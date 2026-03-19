import { Buffer } from "node:buffer";

export function encodeFrame(message) {
  const payload = Buffer.from(JSON.stringify(message), "utf8");
  const frame = Buffer.allocUnsafe(4 + payload.length);
  frame.writeUInt32BE(payload.length, 0);
  payload.copy(frame, 4);
  return frame;
}

export function createFrameParser(onMessage) {
  let buffer = Buffer.alloc(0);

  return function parseChunk(chunk) {
    buffer = Buffer.concat([buffer, chunk]);

    while (buffer.length >= 4) {
      const length = buffer.readUInt32BE(0);
      if (buffer.length < 4 + length) {
        return;
      }

      const payload = buffer.subarray(4, 4 + length);
      buffer = buffer.subarray(4 + length);

      let parsed;
      try {
        parsed = JSON.parse(payload.toString("utf8"));
      } catch {
        continue;
      }

      onMessage(parsed);
    }
  };
}
