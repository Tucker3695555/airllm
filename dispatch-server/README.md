# Dispatch Server

A small Express server that receives task dispatches over HTTP and appends them to a local queue file (`dispatch-queue.jsonl`), one JSON object per line. Downstream tooling (Cursor, a watcher script, etc.) can tail or consume that file.

## Setup

```bash
cd dispatch-server
npm install
npm start
```

The server listens on port `3000` by default. Configure with environment variables:

- `PORT` — port to listen on (default `3000`)
- `QUEUE_FILE` — path of the queue file (default `dispatch-server/dispatch-queue.jsonl`)

## API

### `POST /dispatch`

Dispatch a task. Both fields are required.

```bash
curl -X POST http://localhost:3000/dispatch \
  -H 'Content-Type: application/json' \
  -d '{"task": "refactor auth module", "project": "airllm"}'
```

Response:

```json
{ "status": "received", "task": "refactor auth module", "project": "airllm" }
```

Each accepted dispatch is appended to the queue file as:

```json
{ "task": "refactor auth module", "project": "airllm", "receivedAt": "2026-07-03T00:00:00.000Z" }
```

### `GET /health`

Returns `{ "status": "ok" }` — useful for liveness checks.
