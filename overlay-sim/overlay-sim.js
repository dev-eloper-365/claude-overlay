#!/usr/bin/env node
import net from "node:net";
import path from "node:path";
import readline from "node:readline";

import { createFrameParser, encodeFrame } from "../ipc-server/src/framing.js";

function socketPath() {
  return process.env.OVERLAY_SOCKET || path.join("/tmp", `claude-overlay-${process.getuid()}.sock`);
}

function writeDecision(socket, requestId, decision) {
  socket.write(
    encodeFrame({
      jsonrpc: "2.0",
      id: `decision_${Date.now()}`,
      method: "overlay.decision",
      params: {
        requestId,
        decision
      }
    })
  );
}

function printPrompt(prompt) {
  process.stdout.write("\n");
  process.stdout.write("=== CLAUDE OVERLAY (SIM) ===\n");
  process.stdout.write(`${prompt.riskLevel.toUpperCase()} | ${prompt.toolName}\n`);
  process.stdout.write(`${prompt.description}\n`);
  if (prompt.parameters && Object.keys(prompt.parameters).length > 0) {
    process.stdout.write(`${JSON.stringify(prompt.parameters)}\n`);
  }
  process.stdout.write(`Queued after this: ${prompt.queueDepth}\n`);
  process.stdout.write("Enter/Space = approve, Esc/Backspace = deny\n");
}

function start() {
  const socket = net.createConnection(socketPath());
  const parse = createFrameParser((message) => {
    if (message.method === "overlay.prompt") {
      const prompt = message.params;
      printPrompt(prompt);
      state.currentRequestId = prompt.requestId;
      return;
    }

    if (message.error) {
      process.stderr.write(`[overlay-sim] error: ${message.error.message}\n`);
    }
  });

  const state = {
    currentRequestId: null
  };

  socket.on("connect", () => {
    process.stdout.write(`[overlay-sim] connected to ${socketPath()}\n`);
    socket.write(
      encodeFrame({
        jsonrpc: "2.0",
        id: "sub_1",
        method: "overlay.subscribe",
        params: {}
      })
    );
  });

  socket.on("data", parse);

  socket.on("error", (error) => {
    process.stderr.write(`[overlay-sim] socket error: ${error.message}\n`);
    process.exitCode = 1;
  });

  socket.on("close", () => {
    process.stdout.write("[overlay-sim] disconnected\n");
  });

  readline.emitKeypressEvents(process.stdin);
  if (process.stdin.isTTY) {
    process.stdin.setRawMode(true);
  }

  process.stdin.on("keypress", (_, key) => {
    if (!state.currentRequestId) {
      if (key.ctrl && key.name === "c") {
        process.exit(0);
      }
      return;
    }

    if (key.name === "return" || key.name === "space") {
      writeDecision(socket, state.currentRequestId, "approved");
      state.currentRequestId = null;
      process.stdout.write("[overlay-sim] approved\n");
      return;
    }

    if (key.name === "escape" || key.name === "backspace") {
      writeDecision(socket, state.currentRequestId, "denied");
      state.currentRequestId = null;
      process.stdout.write("[overlay-sim] denied\n");
      return;
    }

    if (key.ctrl && key.name === "c") {
      process.exit(0);
    }
  });
}

start();
