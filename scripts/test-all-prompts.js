#!/usr/bin/env node
/**
 * Test all overlay prompt types
 * Usage: ./test-all-prompts.js [type]
 * Types: binary, choice, multi, input, all
 */

import net from "node:net";
import path from "node:path";
import { createFrameParser, encodeFrame } from "../ipc-server/src/framing.js";

const socketPath = process.env.OVERLAY_SOCKET || `/tmp/claude-overlay-${process.getuid()}.sock`;

function sendRequest(params) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection(socketPath);
    const timeout = setTimeout(() => {
      reject(new Error("Timeout"));
      socket.end();
    }, 30000);

    const parse = createFrameParser((message) => {
      if (message.id === params.requestId) {
        clearTimeout(timeout);
        resolve(message.result);
        socket.end();
      }
    });

    socket.on("data", parse);
    socket.on("error", reject);
    socket.on("connect", () => {
      socket.write(encodeFrame({
        jsonrpc: "2.0",
        id: params.requestId,
        method: "permission.request",
        params
      }));
    });
  });
}

const testCases = {
  binary: {
    name: "Binary (Approve/Deny)",
    params: {
      requestId: `test_binary_${Date.now()}`,
      toolName: "Bash",
      promptType: "binary",
      question: "Allow Bash?",
      description: "Execute shell command",
      parameters: { command: "npm install lodash" },
      riskLevel: "high",
      timestamp: new Date().toISOString(),
      sessionId: "test-session",
      options: [],
      allowOther: false
    }
  },

  choice: {
    name: "Single Choice",
    params: {
      requestId: `test_choice_${Date.now()}`,
      toolName: "AskUserQuestion",
      promptType: "choice",
      question: "Which database should we use?",
      description: "Select your preferred database",
      parameters: {},
      riskLevel: "medium",
      timestamp: new Date().toISOString(),
      sessionId: "test-session",
      options: [
        { label: "PostgreSQL (Recommended)", value: "postgres", description: "Robust, full-featured SQL database" },
        { label: "MySQL", value: "mysql", description: "Popular open-source database" },
        { label: "SQLite", value: "sqlite", description: "Lightweight file-based database" },
        { label: "MongoDB", value: "mongo", description: "NoSQL document database" }
      ],
      allowOther: true,
      placeholder: "Enter custom database..."
    }
  },

  multi: {
    name: "Multi-Select",
    params: {
      requestId: `test_multi_${Date.now()}`,
      toolName: "AskUserQuestion",
      promptType: "multi",
      question: "Which features do you want to enable?",
      description: "Select all that apply",
      parameters: {},
      riskLevel: "low",
      timestamp: new Date().toISOString(),
      sessionId: "test-session",
      options: [
        { label: "Authentication", value: "auth", description: "User login and registration" },
        { label: "Dark Mode", value: "dark", description: "Dark theme support" },
        { label: "Analytics", value: "analytics", description: "Usage tracking" },
        { label: "Notifications", value: "notifications", description: "Push notifications" }
      ],
      allowOther: true,
      placeholder: "Enter custom feature..."
    }
  },

  input: {
    name: "Text Input",
    params: {
      requestId: `test_input_${Date.now()}`,
      toolName: "AskUserQuestion",
      promptType: "input",
      question: "What should the API endpoint be called?",
      description: "Enter the endpoint name",
      parameters: {},
      riskLevel: "low",
      timestamp: new Date().toISOString(),
      sessionId: "test-session",
      options: [],
      allowOther: false,
      placeholder: "/api/v1/..."
    }
  }
};

async function runTest(testName) {
  const test = testCases[testName];
  if (!test) {
    console.error(`Unknown test: ${testName}`);
    return;
  }

  console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(`Testing: ${test.name}`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(`Question: ${test.params.question}`);
  if (test.params.options.length > 0) {
    console.log(`Options:`);
    test.params.options.forEach((opt, i) => console.log(`  ${i + 1}. ${opt.label}`));
  }
  console.log(`\n⏳ Waiting for overlay response...\n`);

  try {
    // Update requestId to be unique
    test.params.requestId = `test_${testName}_${Date.now()}`;
    const result = await sendRequest(test.params);
    console.log(`✅ Response received:`);
    console.log(JSON.stringify(result, null, 2));
  } catch (error) {
    console.error(`❌ Error: ${error.message}`);
  }
}

async function main() {
  const type = process.argv[2] || "all";

  console.log(`\n🧪 Claude Overlay Prompt Type Tests`);
  console.log(`Socket: ${socketPath}`);

  if (type === "all") {
    for (const testName of Object.keys(testCases)) {
      await runTest(testName);
      // Small delay between tests
      await new Promise(r => setTimeout(r, 500));
    }
  } else if (testCases[type]) {
    await runTest(type);
  } else {
    console.error(`\nUsage: ./test-all-prompts.js [type]`);
    console.error(`Types: binary, choice, multi, input, all`);
    process.exit(1);
  }

  console.log(`\n✨ Tests complete!\n`);
}

main().catch(console.error);
