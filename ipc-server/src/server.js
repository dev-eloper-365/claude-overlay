import fs from "node:fs";
import net from "node:net";
import path from "node:path";
import process from "node:process";

import { createFrameParser, encodeFrame } from "./framing.js";

function defaultSocketPath() {
  const uid = typeof process.getuid === "function" ? process.getuid() : process.env.USER || "user";
  return path.join("/tmp", `claude-overlay-${uid}.sock`);
}

function nowIso() {
  return new Date().toISOString();
}

export class OverlayIpcServer {
  constructor(socketPath = process.env.OVERLAY_SOCKET || defaultSocketPath()) {
    this.socketPath = socketPath;
    this.server = null;
    this.overlayClient = null;
    this.queue = [];
    this.inFlight = null;
    this.pendingRequests = new Map();
  }

  start() {
    return new Promise((resolve, reject) => {
      if (this.server) {
        resolve();
        return;
      }

      if (fs.existsSync(this.socketPath)) {
        fs.unlinkSync(this.socketPath);
      }

      this.server = net.createServer((socket) => this.#onConnection(socket));

      this.server.once("error", (error) => reject(error));
      this.server.listen(this.socketPath, () => {
        console.log(`[ipc-server] listening on ${this.socketPath}`);
        resolve();
      });

      this.server.on("close", () => {
        if (fs.existsSync(this.socketPath)) {
          fs.unlinkSync(this.socketPath);
        }
      });
    });
  }

  stop() {
    return new Promise((resolve) => {
      if (!this.server) {
        resolve();
        return;
      }

      const server = this.server;
      this.server = null;
      server.close(() => resolve());
    });
  }

  #onConnection(socket) {
    const parse = createFrameParser((message) => this.#onMessage(socket, message));

    socket.on("data", parse);
    socket.on("error", (error) => {
      console.error("[ipc-server] socket error", error.message);
    });

    socket.on("close", () => {
      if (this.overlayClient === socket) {
        this.overlayClient = null;
      }
    });
  }

  #send(socket, message) {
    if (socket.destroyed) {
      return;
    }
    socket.write(encodeFrame(message));
  }

  #sendError(socket, id, code, message) {
    this.#send(socket, {
      jsonrpc: "2.0",
      id,
      error: { code, message }
    });
  }

  #sendResult(socket, id, result) {
    this.#send(socket, {
      jsonrpc: "2.0",
      id,
      result
    });
  }

  #onMessage(socket, message) {
    if (!message || message.jsonrpc !== "2.0") {
      this.#sendError(socket, null, -32600, "Invalid Request");
      return;
    }

    const { id, method, params } = message;

    if (method === "ping") {
      this.#sendResult(socket, id, { timestamp: nowIso(), queueDepth: this.queue.length });
      return;
    }

    if (method === "overlay.subscribe") {
      this.overlayClient = socket;
      this.#sendResult(socket, id, { subscribed: true, timestamp: nowIso() });
      this.#pumpQueue();
      return;
    }

    if (method === "permission.request") {
      if (!id) {
        this.#sendError(socket, id, -32600, "permission.request requires an id");
        return;
      }

      const requestId = params?.requestId;
      if (!requestId || !params?.toolName) {
        this.#sendError(socket, id, -32004, "Malformed parameters");
        return;
      }

      const queuedAtMs = Date.now();
      this.pendingRequests.set(requestId, { socket, id, queuedAtMs });
      this.queue.push({ ...params, queuedAtMs });
      this.#pumpQueue();
      return;
    }

    if (method === "overlay.decision") {
      const requestId = params?.requestId;
      const decision = params?.decision;
      if (!requestId || !decision) {
        this.#sendError(socket, id, -32004, "Malformed parameters");
        return;
      }

      this.#handleDecision(requestId, decision, {
        ruleSaved: params?.ruleSaved === true,
        ruleId: params?.ruleId,
        selectedValues: params?.selectedValues,
        textInput: params?.textInput
      });
      this.#sendResult(socket, id, { ok: true, timestamp: nowIso() });
      return;
    }

    this.#sendError(socket, id, -32601, `Method not found: ${method}`);
  }

  #pumpQueue() {
    if (!this.overlayClient || this.inFlight || this.queue.length === 0) {
      return;
    }

    const next = this.queue.shift();
    this.inFlight = next.requestId;
    this.#send(this.overlayClient, {
      jsonrpc: "2.0",
      method: "overlay.prompt",
      params: {
        ...next,
        queueDepth: this.queue.length
      }
    });
  }

  #handleDecision(requestId, decision, options = {}) {
    const pending = this.pendingRequests.get(requestId);
    if (!pending) {
      this.inFlight = null;
      this.#pumpQueue();
      return;
    }

    const latency = Math.max(0, Date.now() - pending.queuedAtMs);
    this.#sendResult(pending.socket, pending.id, {
      decision,
      timestamp: nowIso(),
      latency,
      ruleSaved: options.ruleSaved || false,
      ...(options.ruleId ? { ruleId: options.ruleId } : {}),
      ...(options.selectedValues ? { selectedValues: options.selectedValues } : {}),
      ...(options.textInput ? { textInput: options.textInput } : {})
    });

    this.pendingRequests.delete(requestId);
    this.inFlight = null;
    this.#pumpQueue();
  }
}
