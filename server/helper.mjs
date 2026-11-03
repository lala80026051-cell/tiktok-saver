// HELPER PROGRAM — runs on YOUR computer only (127.0.0.1), never on the internet.
// The website page sends it a TikTok link. It asks yt-dlp to save the video(s)
// into your Downloads folder, in a folder called "TikTok Saver".
// Start it with:  npm run helper
import http from 'node:http';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import os from 'node:os';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const PORT = 4330;
const here = path.dirname(fileURLToPath(import.meta.url));
const ytdlp = process.env.YTDLP_PATH ?? path.resolve(here, '..', '..', 'tools', 'yt-dlp', 'yt-dlp.exe');
const outDir = path.join(os.homedir(), 'Downloads', 'TikTok Saver');

// Only pages from this computer may talk to the helper.
const allowedOrigin = /^http:\/\/(localhost|127\.0\.0\.1):\d+$/;

// Only real TikTok links are accepted.
function isTikTok(text) {
  try {
    const url = new URL(text);
    const host = url.hostname;
    return (url.protocol === 'https:' || url.protocol === 'http:') && (host === 'tiktok.com' || host.endsWith('.tiktok.com'));
  } catch {
    return false;
  }
}

const jobs = new Map();

function startJob(link, mode) {
  const job = { id: randomUUID(), status: 'running', files: [], message: '', folder: outDir };
  jobs.set(job.id, job);

  const args = [
    '--newline',
    '--no-simulate',
    '--print', 'after_move:filepath',
    '--no-warnings',
    '-P', outDir,
    '-o', '%(uploader)s/%(upload_date)s_%(id)s.%(ext)s',
    '--windows-filenames',
    '--ignore-errors',
  ];
  if (mode === 'one') args.push('--no-playlist');
  args.push('--', link);

  const child = spawn(ytdlp, args, { windowsHide: true });
  let errors = '';
  let buffer = '';
  child.stdout.on('data', (chunk) => {
    buffer += chunk;
    const lines = buffer.split(/\r?\n/);
    buffer = lines.pop() ?? '';
    for (const line of lines) if (line.trim()) job.files.push(line.trim());
  });
  child.stderr.on('data', (chunk) => {
    errors += chunk;
  });
  child.on('error', (err) => {
    job.status = 'error';
    job.message = `Could not start yt-dlp: ${err.message}`;
  });
  child.on('close', () => {
    if (buffer.trim()) job.files.push(buffer.trim());
    if (job.status === 'error') return;
    if (job.files.length > 0) {
      job.status = 'done';
    } else {
      job.status = 'error';
      job.message = errors.trim().split('\n').slice(-3).join(' ') || 'No video was saved.';
    }
  });
  return job;
}

function send(res, origin, code, body) {
  res.writeHead(code, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': origin ?? 'null',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  });
  res.end(JSON.stringify(body));
}

const server = http.createServer((req, res) => {
  const origin = req.headers.origin;
  if (origin && !allowedOrigin.test(origin)) return send(res, null, 403, { error: 'Not allowed' });
  if (req.method === 'OPTIONS') return send(res, origin, 204, {});

  if (req.method === 'POST' && req.url === '/download') {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk;
      if (body.length > 10_000) req.destroy();
    });
    req.on('end', () => {
      let data;
      try {
        data = JSON.parse(body);
      } catch {
        return send(res, origin, 400, { error: 'Bad request' });
      }
      if (typeof data.link !== 'string' || !isTikTok(data.link.trim())) return send(res, origin, 400, { error: 'Not a TikTok link' });
      const job = startJob(data.link.trim(), data.mode === 'all' ? 'all' : 'one');
      send(res, origin, 200, { id: job.id });
    });
    return;
  }

  const match = req.method === 'GET' && req.url?.match(/^\/status\/([0-9a-f-]{36})$/);
  if (match) {
    const job = jobs.get(match[1]);
    if (!job) return send(res, origin, 404, { error: 'Unknown job' });
    return send(res, origin, 200, { status: job.status, count: job.files.length, message: job.message, folder: job.folder });
  }

  send(res, origin, 404, { error: 'Not found' });
});

if (!fs.existsSync(ytdlp)) {
  console.error(`yt-dlp not found at: ${ytdlp}`);
  process.exit(1);
}
fs.mkdirSync(outDir, { recursive: true });
server.listen(PORT, '127.0.0.1', () => {
  console.log(`Helper is ready on http://127.0.0.1:${PORT}`);
  console.log(`Videos are saved in: ${outDir}`);
});
