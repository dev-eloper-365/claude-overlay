#!/usr/bin/env node
/**
 * live-demo.js — Self-contained live demo of the Permission Overlay round-trip.
 *
 * Starts the IPC server in-process, connects a terminal overlay renderer, then
 * fires 5 realistic permission requests across all risk levels, auto-deciding
 * each after a short pause so you can see the full flow.
 *
 * Usage:  node scripts/live-demo.js
 */

import net from "node:net";
import { setTimeout as sleep } from "node:timers/promises";
import { createFrameParser, encodeFrame } from "../ipc-server/src/framing.js";
import { OverlayIpcServer } from "../ipc-server/src/server.js";

// ─── ANSI helpers ────────────────────────────────────────────────────────────
const C = {
  reset:   "\x1b[0m",
  bold:    "\x1b[1m",
  dim:     "\x1b[2m",
  blue:    "\x1b[34m",
  cyan:    "\x1b[36m",
  yellow:  "\x1b[33m",
  red:     "\x1b[31m",
  green:   "\x1b[32m",
  magenta: "\x1b[35m",
  white:   "\x1b[97m",
  bgBlue:  "\x1b[44m",
  bgRed:   "\x1b[41m",
};

function riskColor(level) {
  switch (level) {
    case "low":      return C.blue;
    case "medium":   return C.yellow;
    case "high":     return C.red;
    case "critical": return C.magenta;
    default:         return C.white;
  }
}

function riskIcon(level) {
  switch (level) {
    case "low":      return "🔵";
    case "medium":   return "🟡";
    case "high":     return "🔴";
    case "critical": return "🚨";
    default:         return "⚪";
  }
}

function decisionStyle(decision) {
  return decision === "approved"
    ? `${C.bold}${C.green}✅ APPROVED${C.reset}`
    : `${C.bold}${C.red}❌ DENIED${C.reset}`;
}

function drawOverlay(prompt, queueDepth) {
  const W = 54;
  const border = "─".repeat(W - 2);
  const rc = riskColor(prompt.riskLevel);
  const icon = riskIcon(prompt.riskLevel);
  const title = `${icon}  ${prompt.riskLevel.toUpperCase()} RISK  |  ${prompt.toolName}`;
  const queueStr = queueDepth > 0 ? `●${queueDepth}` : "  ";

  const pad = (s, len) => {
    const plain = s.replace(/\x1b\[[0-9;]*m/g, "");
    return s + " ".repeat(Math.max(0, len - plain.length));
  };

  const inner = W - 4; // content width inside borders

  console.log(`\n${C.dim}┌${border}┐${C.reset}`);
  console.log(`${C.dim}│${C.reset} ${rc}${C.bold}${pad(title, inner - 3)}${C.reset} ${C.dim}${queueStr} │${C.reset}`);
  console.log(`${C.dim}├${border}┤${C.reset}`);

  // Command / file_path line
  const cmdLabel = prompt.command
    ? `${C.dim}cmd:${C.reset} ${C.cyan}${prompt.command}${C.reset}`
    : prompt.filePath
      ? `${C.dim}file:${C.reset} ${C.cyan}${prompt.filePath}${C.reset}`
      : "";
  if (cmdLabel) console.log(`${C.dim}│${C.reset} ${pad(cmdLabel, inner)} ${C.dim}│${C.reset}`);

  // Description
  console.log(`${C.dim}│${C.reset} ${pad(`${C.dim}${prompt.description}${C.reset}`, inner)} ${C.dim}│${C.reset}`);

  console.log(`${C.dim}├${border}┤${C.reset}`);

  const decisionHint = `${C.green}[Approve ↵]${C.reset}      ${C.red}[Deny ⎋]${C.reset}`;
  console.log(`${C.dim}│${C.reset} ${pad(decisionHint, inner)} ${C.dim}│${C.reset}`);
  console.log(`${C.dim}└${border}┘${C.reset}`);
}

// ─── Demo scenarios ───────────────────────────────────────────────────────────
const SCENARIOS = [
  {
    toolName:    "Read",
    description: "Read source file for context",
    riskLevel:   "low",
    parameters:  { file_path: "src/server.js" },
    decision:    "approved",
    delayMs:     1400,
  },
  {
    toolName:    "Edit",
    description: "Patch a configuration value",
    riskLevel:   "medium",
    parameters:  { file_path: "src/config.json" },
    decision:    "approved",
    delayMs:     1600,
  },
  {
    toolName:    "Bash",
    description: "Run test suite",
    riskLevel:   "high",
    parameters:  { command: "npm test" },
    decision:    "approved",
    delayMs:     1800,
  },
  {
    toolName:    "Bash",
    description: "Force-push to remote branch",
    riskLevel:   "critical",
    parameters:  { command: "git push --force origin main" },
    decision:    "denied",
    delayMs:     2200,
  },
  {
    toolName:    "Bash",
    description: "Clean old build artifacts",
    riskLevel:   "critical",
    parameters:  { command: "rm -rf /tmp/old-build" },
    decision:    "approved",
    delayMs:     2000,
  },
];

// ─── IPC client helpers ───────────────────────────────────────────────────────
function connectClient(socketPath) {
  return new Promise((resolve, reject) => {
    const sock = net.createConnection(socketPath);
    sock.once("connect", () => resolve(sock));
    sock.once("error", reject);
  });
}

function sendMsg(socket, msg) {
  socket.write(encodeFrame(msg));
}

function waitForResponse(socket, matchId) {
  return new Promise((resolve) => {
    const parser = createFrameParser((msg) => {
      if (msg.id === matchId) resolve(msg);
    });
    socket.on("data", parser);
  });
}

// ─── Main ─────────────────────────────────────────────────────────────────────
const SOCK = `/tmp/claude-overlay-demo-${process.pid}.sock`;

(async () => {
  console.clear();
  console.log(`${C.bold}${C.cyan}Claude Code — Permission Overlay  LIVE DEMO${C.reset}`);
  console.log(`${C.dim}${"─".repeat(54)}${C.reset}`);
  console.log(`${C.dim}Socket:${C.reset} ${SOCK}`);
  console.log(`${C.dim}Scenarios:${C.reset} ${SCENARIOS.length} requests across all risk levels\n`);

  // Start server
  const server = new OverlayIpcServer(SOCK);
  await server.start();
  console.log(`${C.green}▶ IPC server started${C.reset}`);

  // Connect overlay subscriber
  const overlaySock = await connectClient(SOCK);
  const overlayMsgs = [];
  const parseOverlay = createFrameParser((m) => overlayMsgs.push(m));
  overlaySock.on("data", parseOverlay);

  sendMsg(overlaySock, { jsonrpc: "2.0", id: "sub_demo", method: "overlay.subscribe", params: {} });
  await sleep(120);
  console.log(`${C.green}▶ Overlay subscriber connected${C.reset}\n`);

  // Wait for an overlay.prompt notification arriving on the overlay socket
  function waitForPrompt() {
    return new Promise((resolve) => {
      function check() {
        const idx = overlayMsgs.findIndex((m) => m.method === "overlay.prompt");
        if (idx !== -1) {
          resolve(overlayMsgs.splice(idx, 1)[0]);
        } else {
          setTimeout(check, 30);
        }
      }
      check();
    });
  }

  // Connect hook client (sends permission.request calls)
  const hookSock = await connectClient(SOCK);
  const hookResponses = new Map();
  const parseHook = createFrameParser((m) => {
    if (m.id) hookResponses.set(m.id, m);
  });
  hookSock.on("data", parseHook);

  function waitHookResponse(id) {
    return new Promise((resolve) => {
      function check() {
        if (hookResponses.has(id)) {
          resolve(hookResponses.get(id));
          hookResponses.delete(id);
        } else {
          setTimeout(check, 30);
        }
      }
      check();
    });
  }

  // ─── Run scenarios ──────────────────────────────────────────────────────────
  const results = [];

  for (let i = 0; i < SCENARIOS.length; i++) {
    const s = SCENARIOS[i];
    const requestId = `demo_req_${i}_${Date.now()}`;
    const rpcId = `hook_${i}`;

    console.log(`${C.dim}[${ i + 1 }/${SCENARIOS.length}]${C.reset} Sending ${C.bold}${s.toolName}${C.reset} request…`);

    // Send hook request
    sendMsg(hookSock, {
      jsonrpc: "2.0",
      id: rpcId,
      method: "permission.request",
      params: {
        requestId,
        toolName:    s.toolName,
        description: s.description,
        riskLevel:   s.riskLevel,
        parameters:  s.parameters,
        timestamp:   new Date().toISOString(),
        sessionId:   "demo-session",
      },
    });

    // Wait for overlay to receive the prompt
    const promptMsg = await waitForPrompt();
    const p = promptMsg.params;

    drawOverlay(
      {
        toolName:    p.toolName,
        description: p.description,
        riskLevel:   p.riskLevel,
        command:     s.parameters.command,
        filePath:    s.parameters.file_path,
      },
      p.queueDepth
    );

    // Pause so the overlay is visible, then auto-decide
    await sleep(s.delayMs);

    const decisionId = `decision_${i}_${Date.now()}`;
    sendMsg(overlaySock, {
      jsonrpc: "2.0",
      id: decisionId,
      method: "overlay.decision",
      params: { requestId, decision: s.decision },
    });

    // Wait for hook response (carries latency)
    const hookResp = await waitHookResponse(rpcId);
    const latency = hookResp?.result?.latency ?? s.delayMs;

    console.log(`     ${decisionStyle(s.decision)}  ${C.dim}(${latency}ms)${C.reset}\n`);
    results.push({ ...s, latency, ok: !hookResp?.error });

    await sleep(300);
  }

  // ─── Summary ────────────────────────────────────────────────────────────────
  console.log(`${C.dim}${"─".repeat(54)}${C.reset}`);
  console.log(`${C.bold}Demo complete — ${SCENARIOS.length}/${SCENARIOS.length} requests processed${C.reset}\n`);

  console.log(`${C.bold}${"Tool".padEnd(14)}${"Risk".padEnd(11)}${"Decision".padEnd(12)}Latency${C.reset}`);
  console.log(`${"─".repeat(54)}`);
  for (const r of results) {
    const rc = riskColor(r.riskLevel);
    const dec = r.decision === "approved" ? `${C.green}approved${C.reset}` : `${C.red}denied${C.reset}  `;
    console.log(
      `${r.toolName.padEnd(14)}${rc}${r.riskLevel.padEnd(11)}${C.reset}${dec}  ${C.dim}${r.latency}ms${C.reset}`
    );
  }
  console.log(`${"─".repeat(54)}`);
  console.log(`${C.dim}All decisions routed through the JSON-RPC IPC server.${C.reset}`);
  console.log(`${C.dim}In production the overlay panel appears system-wide.${C.reset}\n`);

  // Cleanup
  overlaySock.destroy();
  hookSock.destroy();
  await server.stop();
})();
