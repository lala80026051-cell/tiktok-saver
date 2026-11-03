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
// Where videos go unless the page picks another folder with "Choose folder".
const defaultDir = path.join(os.homedir(), 'Downloads', 'TikTok Saver');

// Turns the folder the page sent into a real folder on this computer.
// Anything that is not a full path, or cannot be made, falls back to the default.
function resolveFolder(wanted) {
  if (typeof wanted !== 'string' || !path.isAbsolute(wanted)) return defaultDir;
  try {
    fs.mkdirSync(wanted, { recursive: true });
    return wanted;
  } catch {
    return defaultDir;
  }
}

// Opens the normal Windows "choose a folder" window and gives back the folder picked,
// or null if the person pressed Cancel.
function chooseFolder(startFolder) {
  return new Promise((resolve) => {
    const script = [
      'Add-Type -AssemblyName System.Windows.Forms',
      '[Console]::OutputEncoding = [System.Text.Encoding]::UTF8',
      '$owner = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true }',
      '$dialog = New-Object System.Windows.Forms.FolderBrowserDialog',
      "$dialog.Description = 'Choose where to save your videos'",
      '$dialog.ShowNewFolderButton = $true',
      'if (Test-Path -LiteralPath $env:TS_START) { $dialog.SelectedPath = $env:TS_START }',
      "if ($dialog.ShowDialog($owner) -eq 'OK') { $dialog.SelectedPath }",
    ].join('; ');
    const child = spawn('powershell.exe', ['-NoProfile', '-STA', '-Command', script], {
      env: { ...process.env, TS_START: startFolder },
    });
    let picked = '';
    child.stdout.setEncoding('utf8');
    child.stdout.on('data', (chunk) => {
      picked += chunk;
    });
    child.on('error', () => resolve(null));
    child.on('close', () => resolve(picked.trim() || null));
  });
}

// The website passes requests to the helper through its own address (/helper).
// Other websites cannot add this special header without the browser asking
// first, so a request that has it comes from our own page.
const requiredHeader = 'x-tiktok-saver';

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

// The qualities the page can ask for. TikTok decides what each video really has.
const qualities = ['best', '144', '240', '360', '480', '720', '1080', '1440', '2160'];

// Files are named "001 - caption.mp4", "002 - ...". This finds the next number.
function nextNumber(dir) {
  let highest = 0;
  try {
    for (const name of fs.readdirSync(dir)) {
      const match = name.match(/^(\d+) - /);
      if (match) highest = Math.max(highest, Number(match[1]));
    }
  } catch {
    // The folder cannot be read yet: start at 1.
  }
  return highest + 1;
}

function startJob(link, mode, quality, outDir) {
  const job = { id: randomUUID(), status: 'running', files: [], message: '', folder: outDir };
  jobs.set(job.id, job);

  const name = '%(autonumber)03d - %(title,id).80B';
  const args = [
    '--newline',
    '--no-simulate',
    '--print', 'after_move:%(height)s|%(filepath)s',
    // Also save the full caption in a text file with the same name.
    '--print-to-file', '%(description,title)s', `${outDir}/${name}.txt`,
    '--no-warnings',
    '-P', outDir,
    '-o', `${name}.%(ext)s`,
    '--autonumber-start', String(nextNumber(outDir)),
    '--windows-filenames',
    '--ignore-errors',
  ];
  // "res:720" means: the best quality up to 720p, or the smallest one above it.
  if (quality !== 'best') args.push('-S', `res:${quality}`);
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

function send(res, code, body) {
  res.writeHead(code, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

const server = http.createServer((req, res) => {
  if (req.method === 'OPTIONS') return send(res, 204, {});

  // The page asks this when it opens, to know the helper is ready.
  if (req.method === 'GET' && req.url === '/ping') return send(res, 200, { ok: true, folder: defaultDir });

  // The three requests below change things, so they need the special header.
  if (req.method === 'POST' && ['/download', '/open-folder', '/choose-folder'].includes(req.url ?? '')) {
    if (req.headers[requiredHeader] !== '1') return send(res, 403, { error: 'Not allowed' });
    let body = '';
    req.on('data', (chunk) => {
      body += chunk;
      if (body.length > 10_000) req.destroy();
    });
    req.on('end', async () => {
      let data;
      try {
        data = body ? JSON.parse(body) : {};
      } catch {
        return send(res, 400, { error: 'Bad request' });
      }

      // Opens the folder in Windows File Explorer.
      if (req.url === '/open-folder') {
        spawn('explorer.exe', [resolveFolder(data.folder)], { detached: true, stdio: 'ignore' }).unref();
        return send(res, 200, { ok: true });
      }

      // Shows the Windows "choose a folder" window on this computer.
      if (req.url === '/choose-folder') {
        const picked = await chooseFolder(resolveFolder(data.folder));
        return send(res, 200, { folder: picked });
      }

      if (typeof data.link !== 'string' || !isTikTok(data.link.trim())) return send(res, 400, { error: 'Not a TikTok link' });
      const quality = qualities.includes(String(data.quality)) ? String(data.quality) : 'best';
      const job = startJob(data.link.trim(), data.mode === 'all' ? 'all' : 'one', quality, resolveFolder(data.folder));
      send(res, 200, { id: job.id });
    });
    return;
  }

  const match = req.method === 'GET' && req.url?.match(/^\/status\/([0-9a-f-]{36})$/);
  if (match) {
    const job = jobs.get(match[1]);
    if (!job) return send(res, 404, { error: 'Unknown job' });
    // Each saved line looks like "1080|C:\...\001 - caption.mp4": the quality, then the file.
    const heights = [...new Set(job.files.map((line) => line.split('|')[0]).filter((h) => /^\d+$/.test(h)))];
    return send(res, 200, { status: job.status, count: job.files.length, heights, message: job.message, folder: job.folder });
  }

  send(res, 404, { error: 'Not found' });
});

if (!fs.existsSync(ytdlp)) {
  console.error(`yt-dlp not found at: ${ytdlp}`);
  process.exit(1);
}
fs.mkdirSync(defaultDir, { recursive: true });
server.listen(PORT, '127.0.0.1', () => {
  console.log(`Helper is ready on http://127.0.0.1:${PORT}`);
  console.log(`Videos are saved in: ${defaultDir} (unless you choose another folder on the page)`);
});
