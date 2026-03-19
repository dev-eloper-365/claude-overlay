#!/usr/bin/env node
import net from "node:net";
import path from "node:path";

import { createFrameParser, encodeFrame } from "../ipc-server/src/framing.js";

function socketPath() {
  return process.env.OVERLAY_SOCKET || path.join("/tmp", `claude-overlay-${process.getuid()}.sock`);
}

function classifyRisk(toolName, toolInput) {
  const low = new Set(["Read", "Grep", "Glob", "TodoWrite", "EnterPlanMode", "ExitPlanMode"]);
  const medium = new Set(["Edit", "Write", "NotebookEdit", "Agent", "Skill", "AskUserQuestion"]);
  const high = new Set(["Bash", "WebFetch", "EnterWorktree"]);

  if (toolName === "Bash") {
    const command = String(toolInput?.command || "");
    const destructive = /(rm\s+-rf|git\s+push\s+--force|drop\s+table|sudo\s+)/i.test(command);
    return destructive ? "critical" : "high";
  }

  if (low.has(toolName)) return "low";
  if (medium.has(toolName)) return "medium";
  if (high.has(toolName)) return "high";
  return "medium";
}

function determinePromptType(toolName, toolInput) {
  // AskUserQuestion with options → choice or multiSelect
  if (toolName === "AskUserQuestion") {
    const questions = toolInput?.questions;
    if (Array.isArray(questions) && questions.length > 0) {
      const firstQuestion = questions[0];
      if (firstQuestion.multiSelect === true) {
        return "multi";
      }
      if (Array.isArray(firstQuestion.options) && firstQuestion.options.length > 0) {
        return "choice";
      }
    }
    // No options = text input
    return "input";
  }

  // Default to binary approve/deny
  return "binary";
}

function extractQuestion(toolName, toolInput) {
  if (toolName === "AskUserQuestion") {
    const questions = toolInput?.questions;
    if (Array.isArray(questions) && questions.length > 0) {
      return questions[0].question || "Please respond:";
    }
  }
  return `Allow ${toolName}?`;
}

function extractOptions(toolName, toolInput) {
  if (toolName === "AskUserQuestion") {
    const questions = toolInput?.questions;
    if (Array.isArray(questions) && questions.length > 0) {
      const opts = questions[0].options;
      if (Array.isArray(opts)) {
        return opts.map((opt) => ({
          label: opt.label || String(opt),
          value: opt.value || opt.label || String(opt),
          description: opt.description || null
        }));
      }
    }
  }
  return [];
}

function toPermissionParams(hookPayload) {
  const toolName = hookPayload.tool_name || hookPayload.toolName || "UnknownTool";
  const toolInput = hookPayload.tool_input || hookPayload.parameters || {};
  const requestId = `req_${Date.now()}_${Math.random().toString(16).slice(2, 8)}`;

  const promptType = determinePromptType(toolName, toolInput);
  const question = extractQuestion(toolName, toolInput);
  const options = extractOptions(toolName, toolInput);

  return {
    toolName,
    promptType,
    question,
    description: toolInput.description || `Permission required for ${toolName}`,
    parameters: toolInput,
    riskLevel: classifyRisk(toolName, toolInput),
    timestamp: new Date().toISOString(),
    sessionId: hookPayload.session_id || hookPayload.sessionId || "local-session",
    requestId,
    options,
    allowOther: promptType === "choice" || promptType === "multi", // Allow "Other" for choice prompts
    placeholder: toolInput.placeholder || null,
    metadata: {
      command: typeof toolInput.command === "string" ? toolInput.command : undefined,
      filePath: typeof toolInput.file_path === "string" ? toolInput.file_path : undefined
    }
  };
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks).toString("utf8").trim();
  return raw ? JSON.parse(raw) : {};
}

async function requestDecision(params) {
  return new Promise((resolve, reject) => {
    const timeoutMs = Number(process.env.OVERLAY_REQUEST_TIMEOUT_MS || 30000);
    const socket = net.createConnection(socketPath());
    let settled = false;

    const finish = (fn) => (value) => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(timeout);
      fn(value);
      socket.end();
    };

    const resolveOnce = finish(resolve);
    const rejectOnce = finish(reject);

    const timeout = setTimeout(() => {
      rejectOnce(
        new Error(
          `Overlay decision timeout after ${timeoutMs}ms. Ensure ipc-server and overlay-macos are running.`
        )
      );
    }, timeoutMs);

    const parse = createFrameParser((message) => {
      if (message.id !== params.requestId) {
        return;
      }
      if (message.error) {
        rejectOnce(new Error(message.error.message || "Unknown IPC error"));
      } else {
        resolveOnce(message.result);
      }
    });

    socket.on("data", parse);
    socket.on("error", (error) => {
      rejectOnce(error);
    });

    socket.on("connect", () => {
      socket.write(
        encodeFrame({
          jsonrpc: "2.0",
          id: params.requestId,
          method: "permission.request",
          params
        })
      );
    });
  });
}

function toHookDecision(result, promptType) {
  const d = String(result?.decision || "denied").toLowerCase();

  // For binary prompts
  if (promptType === "binary") {
    if (d === "approved" || d === "approve") {
      return { decision: "approve" };
    }
    return { decision: "deny" };
  }

  // For choice/multi-select prompts
  if (promptType === "choice" || promptType === "multi") {
    if (d === "selected") {
      return {
        decision: "approve",
        selectedValues: result.selectedValues || [],
        textInput: result.textInput || null
      };
    }
    return { decision: "deny" };
  }

  // For text input prompts
  if (promptType === "input") {
    if (d === "input" && result.textInput) {
      return {
        decision: "approve",
        textInput: result.textInput
      };
    }
    return { decision: "deny" };
  }

  return { decision: "deny" };
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

function promptTypeLabel(type) {
  switch (type) {
    case "binary":  return "Approve/Deny";
    case "choice":  return "Single Choice";
    case "multi":   return "Multi-Select";
    case "input":   return "Text Input";
    default:        return type;
  }
}

function printPrompt(params) {
  const r = params.riskLevel;
  const tool = params.toolName;
  const type = params.promptType;
  const cmd = params.parameters?.command;
  const fp = params.parameters?.file_path;
  const detail = cmd || fp || "";

  process.stderr.write(`\n🔒 Permission requested: ${params.question}\n`);
  if (detail) process.stderr.write(`   ${detail}\n`);
  process.stderr.write(`   ${riskIcon(r)} ${r.toUpperCase()} risk • ${promptTypeLabel(type)}\n`);

  if (params.options && params.options.length > 0) {
    process.stderr.write(`   Options:\n`);
    params.options.forEach((opt, i) => {
      process.stderr.write(`     ${i + 1}. ${opt.label}\n`);
    });
  }

  process.stderr.write(`   ⏳ Respond in the overlay...\n\n`);
}

function printResult(hookResult, latencyMs) {
  if (hookResult.decision === "approve") {
    let extra = "";
    if (hookResult.selectedValues) {
      extra = ` [${hookResult.selectedValues.join(", ")}]`;
    }
    if (hookResult.textInput) {
      extra += ` "${hookResult.textInput}"`;
    }
    process.stderr.write(`   ✅ APPROVED${extra} (${(latencyMs / 1000).toFixed(1)}s)\n\n`);
  } else {
    process.stderr.write(`   ❌ DENIED (${(latencyMs / 1000).toFixed(1)}s)\n\n`);
  }
}

(async () => {
  try {
    const hookPayload = await readStdin();
    const params = toPermissionParams(hookPayload);
    printPrompt(params);
    const startMs = Date.now();
    const result = await requestDecision(params);
    const hookResult = toHookDecision(result, params.promptType);
    printResult(hookResult, result?.latency ?? Date.now() - startMs);
    process.stdout.write(`${JSON.stringify(hookResult)}\n`);
  } catch (error) {
    process.stderr.write(`   ⚠️  Overlay error: ${error.message}\n\n`);
    process.stdout.write(`${JSON.stringify({ decision: "deny", error: String(error.message || error) })}\n`);
    process.exitCode = 1;
  }
})();
