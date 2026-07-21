const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const PORT = process.env.PORT || 3000;
const QUEUE_FILE = process.env.QUEUE_FILE || path.join(__dirname, 'dispatch-queue.jsonl');

function readQueue() {
  let raw;
  try {
    raw = fs.readFileSync(QUEUE_FILE, 'utf8');
  } catch (err) {
    if (err.code === 'ENOENT') return [];
    throw err;
  }
  return raw
    .split('\n')
    .filter((line) => line.trim())
    .map((line) => {
      try {
        return JSON.parse(line);
      } catch {
        return null;
      }
    })
    .filter(Boolean);
}

app.post('/dispatch', (req, res) => {
  const { task, project } = req.body || {};

  if (!task || !project) {
    return res.status(400).json({ status: 'error', message: 'Both "task" and "project" are required' });
  }

  console.log(`New dispatch: ${task} → ${project}`);

  const entry = { task, project, receivedAt: new Date().toISOString() };
  fs.appendFile(QUEUE_FILE, JSON.stringify(entry) + '\n', (err) => {
    if (err) {
      console.error(`Failed to write to queue file: ${err.message}`);
      return res.status(500).json({ status: 'error', message: 'Failed to persist dispatch' });
    }
    res.json({ status: 'received', task, project });
  });
});

app.get('/queue', (_req, res) => {
  try {
    res.json({ status: 'ok', entries: readQueue() });
  } catch (err) {
    console.error(`Failed to read queue file: ${err.message}`);
    res.status(500).json({ status: 'error', message: 'Failed to read queue' });
  }
});

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

app.listen(PORT, () => {
  console.log(`Dispatch server running on http://localhost:${PORT}`);
  console.log(`Command dashboard available at http://localhost:${PORT}/`);
});
