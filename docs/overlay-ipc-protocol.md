# Permission Overlay IPC Protocol Specification

## Version 1.0.0

---

## 1. Transport Layer

### 1.1 Primary Transport: Unix Domain Sockets (macOS/Linux)

**Socket Location**:
```
macOS: /tmp/claude-overlay-{user-id}.sock
Linux: /run/user/{uid}/claude-overlay.sock
```

**Socket Configuration**:
- Type: `SOCK_STREAM` (connection-oriented)
- Protocol: TCP-like reliability over local IPC
- Permissions: `0600` (owner read/write only)
- Max connections: 5 (Claude Code + overlay service + 3 debug clients)
- Buffer size: 64KB send, 64KB receive

**Connection Lifecycle**:
```
1. Overlay service creates socket on startup
2. Claude Code connects when first permission needed
3. Connection persists for entire Claude session
4. Graceful shutdown on Claude Code exit
5. Socket file deleted on overlay service termination
```

### 1.2 Fallback Transport: Named Pipes (Windows)

**Pipe Name**:
```
\\.\pipe\claude-overlay-{username}
```

**Pipe Configuration**:
- Type: `PIPE_TYPE_MESSAGE` (message-oriented)
- Mode: `PIPE_READMODE_MESSAGE`
- Max instances: 5
- Buffer size: 64KB in, 64KB out
- Timeout: 5000ms

### 1.3 Secondary Fallback: WebSocket (All Platforms)

**Endpoint**: `ws://127.0.0.1:62341/permission-overlay`

**Use Case**: If Unix socket/named pipe creation fails (permissions, stale socket)

**Security**:
- Bind to localhost only (127.0.0.1, not 0.0.0.0)
- HMAC authentication on connection
- Random port fallback if 62341 occupied

---

## 2. Message Format

### 2.1 JSON-RPC 2.0 Base

All messages follow JSON-RPC 2.0 specification:

```typescript
interface JsonRpcRequest {
  jsonrpc: "2.0";
  id: string | number;        // Unique request identifier
  method: string;              // Method name
  params?: Record<string, any>; // Method parameters
}

interface JsonRpcResponse {
  jsonrpc: "2.0";
  id: string | number;        // Must match request id
  result?: any;                // Success result
  error?: JsonRpcError;        // Error object
}

interface JsonRpcError {
  code: number;                // Error code
  message: string;             // Human-readable error
  data?: any;                  // Additional error context
}
```

### 2.2 Frame Protocol

Messages are framed with length prefix for proper delimiting:

```
┌────────────┬──────────────────────────┐
│ Length     │ JSON Payload             │
│ (4 bytes)  │ (Length bytes)           │
│ Big-endian │ UTF-8 encoded JSON       │
└────────────┴──────────────────────────┘
```

**Example**:
```
Payload: {"jsonrpc":"2.0","id":1,"method":"ping"}
Length: 41 bytes
Frame: [0x00, 0x00, 0x00, 0x29] + UTF-8 JSON
```

**Why Length Prefix?**:
- Handles partial reads from socket
- Enables efficient buffering
- Prevents JSON parsing on incomplete messages

---

## 3. Method Specifications

### 3.1 `permission.request`

**Direction**: Claude Code → Overlay Service

**Purpose**: Request user approval for tool execution

**Parameters**:
```typescript
interface PermissionRequestParams {
  toolName: string;              // Tool identifier (e.g., "Bash", "Edit")
  description: string;           // Human-readable action description
  parameters: Record<string, any>; // Tool-specific parameters
  riskLevel: "low" | "medium" | "high" | "critical";
  timestamp: string;             // ISO 8601 timestamp
  sessionId: string;             // Claude Code conversation session ID
  requestId: string;             // Unique request ID (for deduplication)
  metadata?: {
    filePath?: string;           // File being modified (Edit, Write)
    command?: string;            // Shell command (Bash)
    lineCount?: number;          // Lines affected (Edit)
    destructive?: boolean;       // Marks destructive operations
  };
}
```

**Response**:
```typescript
interface PermissionResponseResult {
  decision: "approved" | "denied" | "deferred";
  timestamp: string;             // ISO 8601 timestamp of decision
  latency: number;               // Time from request to decision (ms)
  ruleSaved: boolean;            // True if user created auto-approve rule
  ruleId?: string;               // ID of created rule (if ruleSaved=true)
  deferUntil?: number;           // Timestamp to re-ask (if deferred)
}
```

**Example Request**:
```json
{
  "jsonrpc": "2.0",
  "id": "req_1710417000123",
  "method": "permission.request",
  "params": {
    "toolName": "Bash",
    "description": "Push commits to remote repository",
    "parameters": {
      "command": "git push origin main",
      "timeout": 120000
    },
    "riskLevel": "high",
    "timestamp": "2026-03-14T10:30:00.123Z",
    "sessionId": "sess_abc123def456",
    "requestId": "req_1710417000123",
    "metadata": {
      "command": "git push origin main",
      "destructive": false
    }
  }
}
```

**Example Response (Approved)**:
```json
{
  "jsonrpc": "2.0",
  "id": "req_1710417000123",
  "result": {
    "decision": "approved",
    "timestamp": "2026-03-14T10:30:02.450Z",
    "latency": 2327,
    "ruleSaved": false
  }
}
```

**Example Response (Denied)**:
```json
{
  "jsonrpc": "2.0",
  "id": "req_1710417000123",
  "result": {
    "decision": "denied",
    "timestamp": "2026-03-14T10:30:01.800Z",
    "latency": 1677,
    "ruleSaved": false
  }
}
```

**Error Codes**:
- `-32001`: Overlay timeout (no user response within 30s)
- `-32002`: Overlay service unavailable
- `-32003`: Invalid risk level
- `-32004`: Malformed parameters

### 3.2 `permission.cancel`

**Direction**: Claude Code → Overlay Service

**Purpose**: Cancel a pending permission request (user interrupted task)

**Parameters**:
```typescript
interface PermissionCancelParams {
  requestId: string; // ID of request to cancel
  reason?: string;   // Optional cancellation reason
}
```

**Response**:
```typescript
interface PermissionCancelResult {
  cancelled: boolean;  // True if request was in queue
  wasVisible: boolean; // True if was currently displayed
}
```

**Example**:
```json
{
  "jsonrpc": "2.0",
  "id": "cancel_001",
  "method": "permission.cancel",
  "params": {
    "requestId": "req_1710417000123",
    "reason": "User stopped task execution"
  }
}
```

### 3.3 `ping`

**Direction**: Bidirectional

**Purpose**: Health check / keepalive

**Parameters**: None

**Response**:
```typescript
interface PingResult {
  timestamp: string;  // Server timestamp
  uptime: number;     // Overlay service uptime (seconds)
  queueDepth: number; // Current queue size
}
```

**Example**:
```json
{
  "jsonrpc": "2.0",
  "id": "ping_001",
  "method": "ping"
}

// Response
{
  "jsonrpc": "2.0",
  "id": "ping_001",
  "result": {
    "timestamp": "2026-03-14T10:30:00.000Z",
    "uptime": 3600,
    "queueDepth": 0
  }
}
```

**Keepalive Schedule**: Every 5 seconds when idle, every 1 second with pending requests

### 3.4 `queue.status`

**Direction**: Claude Code → Overlay Service

**Purpose**: Query current queue state

**Parameters**: None

**Response**:
```typescript
interface QueueStatusResult {
  depth: number;           // Total items in queue
  processing: boolean;     // True if overlay currently showing
  pending: Array<{
    requestId: string;
    toolName: string;
    riskLevel: string;
    enqueuedAt: string;
  }>;
}
```

**Example Response**:
```json
{
  "jsonrpc": "2.0",
  "id": "queue_001",
  "result": {
    "depth": 3,
    "processing": true,
    "pending": [
      {
        "requestId": "req_002",
        "toolName": "Edit",
        "riskLevel": "medium",
        "enqueuedAt": "2026-03-14T10:30:05.000Z"
      },
      {
        "requestId": "req_003",
        "toolName": "Read",
        "riskLevel": "low",
        "enqueuedAt": "2026-03-14T10:30:06.000Z"
      }
    ]
  }
}
```

### 3.5 `rules.list`

**Direction**: Claude Code → Overlay Service

**Purpose**: Retrieve all auto-approve rules

**Parameters**:
```typescript
interface RulesListParams {
  includeExpired?: boolean; // Include expired rules (default: false)
}
```

**Response**:
```typescript
interface RulesListResult {
  rules: Array<{
    id: string;
    pattern: {
      toolName?: string;
      parametersMatch?: Record<string, any>;
    };
    action: "approve" | "deny";
    scope: {
      maxUses?: number;
      usesRemaining?: number;
      expiresAt?: string;
    };
    createdAt: string;
    lastUsed?: string;
  }>;
}
```

### 3.6 `rules.delete`

**Direction**: Claude Code → Overlay Service

**Purpose**: Delete an auto-approve rule

**Parameters**:
```typescript
interface RulesDeleteParams {
  ruleId: string;
}
```

**Response**:
```typescript
interface RulesDeleteResult {
  deleted: boolean;
}
```

### 3.7 `overlay.show` / `overlay.hide`

**Direction**: Claude Code → Overlay Service

**Purpose**: Manually control overlay visibility (for testing)

**Parameters**: None

**Response**:
```typescript
interface OverlayVisibilityResult {
  visible: boolean;
}
```

### 3.8 `history.query`

**Direction**: Claude Code → Overlay Service

**Purpose**: Query decision history

**Parameters**:
```typescript
interface HistoryQueryParams {
  sessionId?: string;      // Filter by session
  toolName?: string;       // Filter by tool
  decision?: "approved" | "denied";
  startDate?: string;      // ISO 8601
  endDate?: string;        // ISO 8601
  limit?: number;          // Max results (default: 100)
  offset?: number;         // Pagination offset
}
```

**Response**:
```typescript
interface HistoryQueryResult {
  total: number;           // Total matching records
  records: Array<{
    requestId: string;
    toolName: string;
    description: string;
    decision: "approved" | "denied";
    timestamp: string;
    latency: number;
    sessionId: string;
  }>;
}
```

---

## 4. Error Codes

### 4.1 Standard JSON-RPC Errors

| Code | Message | Meaning |
|------|---------|---------|
| -32700 | Parse error | Invalid JSON received |
| -32600 | Invalid Request | Missing required fields |
| -32601 | Method not found | Unknown method name |
| -32602 | Invalid params | Parameter validation failed |
| -32603 | Internal error | Server-side exception |

### 4.2 Application-Specific Errors

| Code | Message | Meaning |
|------|---------|---------|
| -32001 | Overlay timeout | User didn't respond within timeout period |
| -32002 | Service unavailable | Overlay service crashed or unreachable |
| -32003 | Invalid risk level | Risk level not in allowed enum |
| -32004 | Malformed parameters | Tool parameters schema mismatch |
| -32005 | Queue full | Too many pending requests (>100) |
| -32006 | Duplicate request | Same requestId already in queue |
| -32007 | Rule not found | Attempted to delete non-existent rule |
| -32008 | Database error | History database write failed |
| -32009 | Permission denied | Operation not allowed in current state |

**Error Response Example**:
```json
{
  "jsonrpc": "2.0",
  "id": "req_001",
  "error": {
    "code": -32001,
    "message": "Overlay timeout after 30s",
    "data": {
      "fallbackAction": "deny",
      "queueDepth": 5,
      "retryable": false
    }
  }
}
```

---

## 5. Connection Handshake

### 5.1 Authentication Flow

```
1. Claude Code connects to socket
   ↓
2. Overlay sends challenge (256-bit nonce)
   ↓
3. Claude Code responds with HMAC(nonce, shared_secret)
   ↓
4. Overlay verifies HMAC
   ↓
5. Connection authenticated (or rejected)
```

**Shared Secret Location**:
```
~/.claude/overlay-secret.key  (256-bit hex string)
```

**Challenge Message**:
```json
{
  "jsonrpc": "2.0",
  "method": "auth.challenge",
  "params": {
    "nonce": "a1b2c3d4e5f6...",
    "algorithm": "HMAC-SHA256"
  }
}
```

**Response Message**:
```json
{
  "jsonrpc": "2.0",
  "method": "auth.response",
  "params": {
    "hmac": "9f8e7d6c5b4a...",
    "clientId": "claude-code",
    "version": "1.0.0"
  }
}
```

### 5.2 Version Negotiation

**Client Sends**:
```json
{
  "jsonrpc": "2.0",
  "id": "version_001",
  "method": "version.negotiate",
  "params": {
    "protocolVersion": "1.0.0",
    "capabilities": ["queue", "rules", "history"]
  }
}
```

**Server Responds**:
```json
{
  "jsonrpc": "2.0",
  "id": "version_001",
  "result": {
    "protocolVersion": "1.0.0",
    "compatible": true,
    "capabilities": ["queue", "rules", "history", "advanced-filters"]
  }
}
```

**Incompatibility**: If versions incompatible, server returns error and closes connection

---

## 6. Performance Considerations

### 6.1 Latency Optimization

**Target Metrics**:
- Socket write: <5ms
- Socket read: <5ms
- JSON parse: <10ms
- Total round-trip: <50ms (excluding user decision time)

**Optimizations**:
- Keep connection open (avoid reconnect overhead)
- Pre-allocate 64KB read buffer
- Use streaming JSON parser (don't buffer entire message)
- Cork socket writes (TCP_CORK/TCP_NODELAY balance)

### 6.2 Throughput

**Expected Load**:
- Typical: 5-10 requests/minute
- Burst: 50 requests in 10 seconds
- Max sustainable: 100 requests/minute

**Buffer Management**:
- Client send buffer: 256KB (allows ~100 queued requests)
- Server receive buffer: 256KB
- Flush on each message (don't batch)

### 6.3 Backpressure

**Queue Limits**:
- Hard limit: 100 pending requests
- Soft limit: 50 pending requests (warning logged)
- If full: Return `-32005` error (queue full)

**Flow Control**:
- Client should wait for response before sending next request
- If queue >50, overlay shows "High queue depth" warning
- If queue >80, requests auto-denied with error

---

## 7. Security Hardening

### 7.1 Socket Permissions

**Unix Socket**:
```bash
chmod 600 /tmp/claude-overlay-{uid}.sock
chown {user}:{group} /tmp/claude-overlay-{uid}.sock
```

**Named Pipe (Windows)**:
```c
SECURITY_ATTRIBUTES sa;
sa.lpSecurityDescriptor = /* DACL: Owner full control only */;
CreateNamedPipe(..., &sa);
```

### 7.2 Message Validation

**Input Sanitization**:
- Max message size: 1MB (reject larger)
- Max string length: 10,000 chars (truncate)
- Allowed characters: Printable ASCII + UTF-8
- Reject control characters (except \n, \r, \t)

**Schema Validation**:
- Use JSON Schema for all params
- Strict mode (no additional properties)
- Type coercion disabled

### 7.3 Rate Limiting

**Per-Connection Limits**:
- Max 200 requests/minute (per connection)
- Max 10 requests/second (burst)
- Exceeded: Return `-32009` (permission denied)

**Global Limits**:
- Max 500 requests/minute (all connections)
- Max 5 concurrent connections

---

## 8. Debugging & Observability

### 8.1 Debug Logging

**Log Levels**:
- `ERROR`: IPC errors, auth failures
- `WARN`: Timeouts, queue warnings
- `INFO`: Connection events, method calls
- `DEBUG`: Full message payloads

**Log Format**:
```
2026-03-14T10:30:00.123Z [INFO] [IPC] Connection established from PID 12345
2026-03-14T10:30:01.456Z [DEBUG] [IPC] → {"method":"permission.request",...}
2026-03-14T10:30:03.789Z [DEBUG] [IPC] ← {"result":{"decision":"approved",...}}
```

### 8.2 Metrics Collection

**Tracked Metrics**:
- Request count (by method, by tool)
- Latency histogram (p50, p95, p99)
- Error rate (by error code)
- Queue depth over time
- Connection count

**Export Format**: Prometheus-compatible metrics endpoint (optional)

### 8.3 Diagnostic Commands

**Dump Queue State**:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"debug.dump"}' | nc -U /tmp/claude-overlay-{uid}.sock
```

**Force Overlay Visibility**:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"overlay.show"}' | nc -U /tmp/claude-overlay-{uid}.sock
```

---

## 9. Testing

### 9.1 Unit Tests

**Mock IPC Client**:
```typescript
class MockIpcClient {
  async request(method: string, params: any): Promise<any> {
    // Simulate 50ms latency
    await sleep(50);
    return mockResponses[method];
  }
}
```

**Test Cases**:
- ✓ Request/response round-trip
- ✓ Error handling (timeout, invalid params)
- ✓ Reconnection logic
- ✓ Message framing (partial reads)
- ✓ Concurrent requests

### 9.2 Integration Tests

**End-to-End Flow**:
1. Start overlay service
2. Connect Claude Code client
3. Send permission.request
4. Simulate user approval (auto-approve after 100ms)
5. Verify response received
6. Check history logged

**Load Testing**:
- Send 1000 requests in 10 seconds
- Verify all processed correctly
- Check memory/CPU usage stable

### 9.3 Chaos Testing

**Failure Injection**:
- Kill overlay service mid-request
- Corrupt socket file
- Send malformed JSON
- Fill queue to capacity
- Simulate network delay (tc/netem)

**Expected Behavior**: Graceful degradation, no crashes

---

## 10. Migration Path

### 10.1 Protocol Versioning

**Version Header**:
```typescript
interface MessageEnvelope {
  protocolVersion: "1.0" | "1.1" | "2.0";
  message: JsonRpcMessage;
}
```

**Compatibility**:
- Overlay supports last 2 major versions
- Clients must send `version.negotiate` on connect
- Deprecated features logged with warnings

### 10.2 Breaking Changes

**Version 1.x → 2.0**:
- `riskLevel` enum values changed
- New required field: `toolVersion`
- Removed: `metadata.destructive` (use riskLevel)

**Migration Strategy**:
1. Add feature flag for v2 protocol
2. Dual-protocol support for 6 months
3. Deprecation warning in logs
4. Hard cutover after grace period

---

## Appendix: Wire Protocol Examples

### Complete Request/Response Cycle

**Raw Socket Data** (Claude Code → Overlay):
```
[Length Header: 4 bytes]
0x00 0x00 0x01 0x2A  (298 bytes)

[JSON Payload: 298 bytes]
{"jsonrpc":"2.0","id":"req_001","method":"permission.request","params":{"toolName":"Bash","description":"List directory contents","parameters":{"command":"ls -la"},"riskLevel":"low","timestamp":"2026-03-14T10:30:00.000Z","sessionId":"sess_123","requestId":"req_001"}}
```

**Raw Socket Data** (Overlay → Claude Code):
```
[Length Header: 4 bytes]
0x00 0x00 0x00 0x7C  (124 bytes)

[JSON Payload: 124 bytes]
{"jsonrpc":"2.0","id":"req_001","result":{"decision":"approved","timestamp":"2026-03-14T10:30:02.500Z","latency":2500,"ruleSaved":false}}
```

**Total Bytes**: 422 request + 128 response = 550 bytes
**Latency**: ~50ms IPC + 2500ms user decision = 2550ms total

---

## Document Metadata
- **Version**: 1.0.0
- **Last Updated**: 2026-03-14
- **Status**: Draft
- **Compatibility**: Permission Overlay Spec v1.0
