import { OverlayIpcServer } from "./server.js";

const server = new OverlayIpcServer();

server.start().catch((error) => {
  console.error("[ipc-server] failed to start", error);
  process.exitCode = 1;
});

process.on("SIGINT", async () => {
  await server.stop();
  process.exit(0);
});

process.on("SIGTERM", async () => {
  await server.stop();
  process.exit(0);
});
