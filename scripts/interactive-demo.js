#!/usr/bin/env node
/**
 * interactive-demo.js
 *
 * Starts the IPC server + native macOS overlay, sends ONE realistic
 * permission request, then waits — with NO timeout — for you to
 * click Approve or Deny in the floating panel that appears on screen.
 *
 * Usage:  node scripts/interactive-demo.js
 */

import net from "node:net";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { setTimeout as sleep } from "node:timers/promises";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT      = path.resolve(__dirname, "..");
const BINARY    = path.join(ROOT, "overlay-macos/.build/arm64-apple-macosx/debug/overlay-macos");
const SOCKET    = `/tmp/claude-overlay-${process.getuid()}.sock`;

const { OverlayIpcServer } = await import(`${ROOT}/ipc-server/src/server.js`);
const { createFrameParser, encodeFrame } = await import(`${ROOT}/ipc-server/src/framing.js`);

// ─── ANSI helpers ─────────────────────────────────────────────────────────────

const C = {
  reset:  "\x1b[0m",
  bold:   "\x1b[1m",
  dim:    "\x1b[2m",
  cyan:   "\x1b[36m",
  green:  "\x1b[32m",
  red:    "\x1b[31m",
  yellow: "\x1b[33m",
};
const c = (col, t) => `${C[col] ?? ""}${t}${C.reset}`;

// ─── The one permission request ───────────────────────────────────────────────

const REQUEST = {
  toolName:    "Bash",
  description: "Permission required for Bash",
  riskLevel:   "critical",
  parameters:  { command: "git push --force origin main" },
  sessionId:   "claude-session-demo",
  timestamp:   new Date().toISOString(),
  requestId:   `req_${Date.now()}`,
};

// ─── Request helper ───────────────────────────────────────────────────────────

function sendRequest(params) {
  return new Promise((resolve, reject) => {
    const sock = net.createConnection(SOCKET);
    let settled = false;
    const finish = (fn) => (v) => { if (!settled) { settled = true; fn(v); sock.end(); } };
    const ok  = finish(resolve);
    const err = finish(reject);
    const parse = createFrameParser((msg) => {
      if (msg.id === params.requestId) {
        msg.error ? err(new Error(msg.error.message)) : ok(msg.result);
      }
    });
    sock.on("data", parse);
    sock.on("error", err);
    sock.on("connect", () => {
      sock.write(encodeFrame({
        jsonrpc: "2.0",
        id: params.requestId,
        method: "permission.request",
        params,
      }));
    });
  });
}

// ─── Main ─────────────────────────────────────────────────────────────────────

(async () => {
  console.log(`\n${c("bold", c("cyan", "  Claude Code — Interactive Permission Demo"))}`);
  console.log(c("dim", "  A native overlay panel will appear on your screen.\n"));

  // 1. Remove stale socket
  try { (await import("node:fs")).unlinkSync(SOCKET); } catch {}

  // 2. Start IPC server
  process.stdout.write(`  ${c("dim", "▸")} Starting IPC server...  `);
  const server = new OverlayIpcServer(SOCKET);
  await server.start();
  console.log(c("green", "ready"));

  // 3. Spawn native macOS overlay
  process.stdout.write(`  ${c("dim", "▸")} Launching macOS overlay... `);
  const overlayProc = spawn(BINARY, [], {
    env: { ...process.env, OVERLAY_SOCKET: SOCKET },
    stdio: "ignore",
  });
  overlayProc.on("error", (e) => {
    console.error(`\n${c("red", "Overlay failed to start:")} ${e.message}`);
    process.exit(1);
  });

  // Give the overlay time to connect
  await sleep(900);
  console.log(c("green", "running"));

  // 4. Announce what's about to happen
  console.log(`
  ${c("bold", "Sending permission request:")}
  ${c("dim", "Tool:")}    ${c("bold", REQUEST.toolName)}
  ${c("dim", "Command:")} ${c("yellow", REQUEST.parameters.command)}
  ${c("dim", "Risk:")}    ${c("red", REQUEST.riskLevel.toUpperCase())}

  ${c("bold", "→ A floating panel will appear at the top of your screen.")}
  ${c("dim", "  Press  Enter / click Approve   to allow.")}
  ${c("dim", "  Press  Esc   / click Deny      to block.")}
  ${c("dim", "  Waiting for your decision…")}
`);

  // 5. Send the request — no timeout, waits until you decide
  let result;
  try {
    result = await sendRequest(REQUEST);
  } catch (e) {
    console.error(c("red", `\n  Error: ${e.message}`));
    overlayProc.kill();
    await server.stop();
    process.exit(1);
  }

  // 6. Show the outcome
  const decision = String(result?.decision ?? "denied").toLowerCase();
  const approved = decision === "approved" || decision === "approve";

  if (approved) {
    console.log(`  ${c("bold", c("green", "✅  APPROVED"))}  ${c("dim", `latency: ${result.latency}ms`)}`);
    console.log(c("dim", `  Claude Code would now execute: ${REQUEST.parameters.command}\n`));
  } else {
    console.log(`  ${c("bold", c("red", "❌  DENIED"))}  ${c("dim", `latency: ${result.latency}ms`)}`);
    console.log(c("dim", "  Claude Code would block the tool call and report it denied.\n"));
  }

  overlayProc.kill();
  await server.stop();
})();
