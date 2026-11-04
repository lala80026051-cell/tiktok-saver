// HELPER PROGRAM — runs on YOUR computer only (127.0.0.1), never on the internet.
// The website page sends it a TikTok link. It asks yt-dlp to save the video(s)
// into your Downloads folder, in a folder called "TikTok Saver".
// Start it with:  npm run helper
import http from 'node:http';
import { spawn, spawnSync } from 'node:child_process';
import { randomUUID, timingSafeEqual } from 'node:crypto';
import os from 'node:os';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const PORT = 4330;
const here = path.dirname(fileURLToPath(import.meta.url));
// yt-dlp is found in this order: the YTDLP_PATH setting, tools\ yt-dlp inside this project
// (made by setup.bat), then a "tools" folder next to the project.
const ytdlpCandidates = [
  process.env.YTDLP_PATH,
  path.resolve(here, '..', 'tools', 'yt-dlp', 'yt-dlp.exe'),
  path.resolve(here, '..', '..', 'tools', 'yt-dlp', 'yt-dlp.exe'),
];
const ytdlp = ytdlpCandidates.find((candidate) => candidate && fs.existsSync(candidate)) ?? ytdlpCandidates[1];
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

// ---- Using the page from another device (a phone, or another computer) ----
// The helper itself only listens on THIS computer (127.0.0.1). A device on the same network opens
// the website, and the website's server passes the device's requests on to the helper. That server
// adds the device's real address at the END of the X-Forwarded-For header. So:
//   - a request with no such address comes from this computer: always allowed;
//   - a request from another device is allowed only with the code (PIN) shown on this computer;
//   - if the helper was started without a code, requests from other devices are refused.
const savedPin = process.env.SAVER_PIN ?? '';
const failures = new Map(); // device address -> { count, until }

function clientAddress(req) {
  const parts = String(req.headers['x-forwarded-for'] ?? '').split(',').map((part) => part.trim()).filter(Boolean);
  return parts.length ? parts[parts.length - 1] : '';
}

function isLocal(req) {
  return ['', '127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(clientAddress(req));
}

function pinMatches(req) {
  const given = Buffer.from(String(req.headers['x-saver-pin'] ?? ''));
  const wanted = Buffer.from(savedPin);
  return given.length === wanted.length && timingSafeEqual(given, wanted);
}

// Returns 'ok', 'pin' (a code is needed), 'locked' (too many wrong codes), or 'closed' (no code was set).
function accessFor(req) {
  if (isLocal(req)) return 'ok';
  if (!savedPin) return 'closed';
  const address = clientAddress(req);
  const record = failures.get(address) ?? { count: 0, until: 0 };
  if (record.until > Date.now()) return 'locked';
  if (pinMatches(req)) {
    failures.delete(address);
    return 'ok';
  }
  if (req.headers['x-saver-pin']) {
    // A wrong code. After 5 wrong codes, this device is locked out for 10 minutes.
    record.count += 1;
    if (record.count >= 5) {
      record.count = 0;
      record.until = Date.now() + 10 * 60 * 1000;
    }
    failures.set(address, record);
  }
  return 'pin';
}

// The video sites this tool accepts. The site is found from the link itself.
const platformHosts = {
  tiktok: ['tiktok.com'],
  youtube: ['youtube.com', 'youtu.be', 'youtube-nocookie.com'],
  facebook: ['facebook.com', 'fb.watch', 'fb.com'],
  instagram: ['instagram.com'],
};

// Returns 'tiktok', 'youtube', 'facebook' or 'instagram' for a link, or null for anything else.
function platformOf(text) {
  try {
    const url = new URL(text);
    if (url.protocol !== 'https:' && url.protocol !== 'http:') return null;
    const host = url.hostname.toLowerCase();
    for (const [name, domains] of Object.entries(platformHosts)) {
      if (domains.some((domain) => host === domain || host.endsWith(`.${domain}`))) return name;
    }
  } catch {
    // Not a link at all.
  }
  return null;
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

// ffmpeg writes the caption onto the picture. It is found in this order: the FFMPEG_PATH
// setting, tools\ffmpeg next to yt-dlp, the one that came with MULTI Tools KH, then the PATH.
function findFfmpeg() {
  const candidates = [
    process.env.FFMPEG_PATH,
    path.resolve(here, '..', 'tools', 'ffmpeg', 'ffmpeg.exe'),
    path.resolve(here, '..', '..', 'tools', 'ffmpeg', 'ffmpeg.exe'),
    path.join(os.homedir(), 'AppData', 'Local', 'Programs', 'MULTI Tools KH', 'system', 'ffmpeg', 'ffmpeg.exe'),
  ];
  for (const candidate of candidates) if (candidate && fs.existsSync(candidate)) return candidate;
  const found = spawnSync('where', ['ffmpeg'], { encoding: 'utf8' });
  const first = found.status === 0 ? found.stdout.split(/\r?\n/)[0].trim() : '';
  return first && fs.existsSync(first) ? first : null;
}
const ffmpeg = findFfmpeg();

// Builds the caption as an ASS subtitle file: it wraps long lines, and it draws Khmer correctly.
function captionFile(text, width, height) {
  const clean = Array.from(
    text
      .replace(/\s+/g, ' ')
      .replace(/[\\{}]/g, '')
      .trim(),
  );
  // The whole caption is shown. A long caption gets smaller letters so that it still fits.
  const shown = clean.join('');
  const base = Math.min(width, height) * 0.045;
  const fit = Math.max(0.45, Math.min(1, Math.sqrt(150 / Math.max(1, clean.length))));
  const size = Math.max(12, Math.round(base * fit));
  const sideMargin = Math.round(width * 0.06);
  const bottomMargin = Math.round(height * 0.07);
  return [
    '[Script Info]',
    'ScriptType: v4.00+',
    `PlayResX: ${width}`,
    `PlayResY: ${height}`,
    'WrapStyle: 0',
    '',
    '[V4+ Styles]',
    'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding',
    `Style: Caption,Khmer UI,${size},&H00FFFFFF,&H00FFFFFF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,${Math.max(2, Math.round(size / 12))},1,2,${sideMargin},${sideMargin},${bottomMargin},1`,
    '',
    '[Events]',
    'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text',
    `Dialogue: 0,0:00:00.00,9:59:59.00,Caption,,0,0,0,,${shown}`,
    '',
  ].join('\n');
}

// Writes the caption onto the video, then replaces the saved file with the new one.
function addCaption(job, file, text, width, height) {
  return new Promise((resolve, reject) => {
    const work = fs.mkdtempSync(path.join(os.tmpdir(), 'tiktok-saver-'));
    const cleanUp = () => fs.rmSync(work, { recursive: true, force: true });
    try {
      fs.writeFileSync(path.join(work, 'caption.ass'), captionFile(text, width, height), 'utf8');
      // KhmerUI draws Khmer and English. The other two draw emoji and symbols.
      for (const font of ['KhmerUI.ttf', 'seguiemj.ttf', 'seguisym.ttf']) {
        const source = path.join('C:\\Windows\\Fonts', font);
        if (fs.existsSync(source)) fs.copyFileSync(source, path.join(work, font));
      }
    } catch (err) {
      cleanUp();
      return reject(err);
    }
    const made = path.join(work, 'captioned.mp4');
    const args = [
      '-y', '-hide_banner', '-loglevel', 'error',
      '-i', file,
      '-vf', 'subtitles=caption.ass:fontsdir=.',
      '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20',
      '-c:a', 'copy',
      '-movflags', '+faststart',
      made,
    ];
    const child = spawn(ffmpeg, args, { cwd: work, windowsHide: true });
    job.current = child; // so the Stop button can stop it
    let errors = '';
    child.stderr.on('data', (chunk) => {
      errors += chunk;
    });
    child.on('error', (err) => {
      cleanUp();
      reject(err);
    });
    child.on('close', (code) => {
      try {
        if (code !== 0 || !fs.existsSync(made)) throw new Error(errors.trim().split('\n').slice(-2).join(' ') || `ffmpeg stopped (code ${code})`);
        fs.copyFileSync(made, `${file}.new`);
        fs.renameSync(`${file}.new`, file);
        resolve();
      } catch (err) {
        reject(err);
      } finally {
        cleanUp();
      }
    });
  });
}

// Stops a running job: its programs are stopped at once (with everything they started),
// and the half-finished download files it left behind are removed.
function stopJob(job) {
  if (job.status !== 'running') return;
  job.stopped = true;
  if (job.current?.pid) spawnSync('taskkill', ['/PID', String(job.current.pid), '/T', '/F'], { windowsHide: true });
}

function removePartialFiles(dir, since) {
  try {
    for (const name of fs.readdirSync(dir)) {
      if (!/\.(part|ytdl|temp|tmp)$|\.part-Frag\d+$|\.new$/i.test(name)) continue;
      const file = path.join(dir, name);
      if (fs.statSync(file).mtimeMs >= since - 2000) fs.rmSync(file, { force: true });
    }
  } catch {
    // The folder cannot be read: nothing to clean.
  }
}

// A link to ONE video (not to an account): a video or photo page, or a short share link.
function isVideoLink(link) {
  try {
    const url = new URL(link);
    const pathName = url.pathname.replace(/\/+$/, '');
    if (/^\/@[^/]+\/(video|photo)\/\d+/.test(pathName)) return true;
    return url.hostname.startsWith('vm.') || url.hostname.startsWith('vt.') || pathName.startsWith('/t/');
  } catch {
    return false;
  }
}

// Some accounts cannot be read from their profile link, because TikTok does not give out the
// account's hidden ID. Every video of the account carries that ID, so we read it from one video.
// Resolves with the ID, or null if it could not be read.
function findAccountId(job, link) {
  return new Promise((resolve) => {
    const child = spawn(ytdlp, ['--no-warnings', '--simulate', '--no-playlist', '--print', '%(channel_id)s', '--', link], { windowsHide: true });
    job.current = child; // so the Stop button can stop it
    let out = '';
    child.stdout.setEncoding('utf8');
    child.stdout.on('data', (chunk) => {
      out += chunk;
    });
    child.on('error', () => resolve(null));
    child.on('close', () => {
      const id = out.trim().split(/\r?\n/)[0] ?? '';
      resolve(/^[\w-]{20,}$/.test(id) ? id : null);
    });
  });
}

function startJob(link, mode, quality, outDir, withCaption) {
  const job = { id: randomUUID(), status: 'running', stage: 'downloading', stopped: false, current: null, files: [], captioned: 0, notes: [], message: '', folder: outDir };
  const startedAt = Date.now();
  const platform = platformOf(link);
  jobs.set(job.id, job);

  const name = '%(autonumber)03d - %(title,id).80B';
  const args = [
    '--newline',
    '--no-simulate',
    // One line of JSON per saved video: its size, its file, and its caption.
    '--print', 'after_move:%(.{height,width,filepath,description,title})j',
    '--no-warnings',
    '-P', outDir,
    '-o', `${name}.%(ext)s`,
    '--autonumber-start', String(nextNumber(outDir)),
    '--windows-filenames',
    '--ignore-errors',
    // YouTube keeps picture and sound apart for big sizes, so they are joined into one mp4.
    '--merge-output-format', 'mp4',
  ];
  if (ffmpeg) args.push('--ffmpeg-location', path.dirname(ffmpeg));
  // "res:720" means: the best quality up to 720p, or the smallest one above it.
  if (quality !== 'best') args.push('-S', `res:${quality}`);
  if (mode === 'one') args.push('--no-playlist');

  // Starts yt-dlp on the final link (the original link, or the account found from a video).
  function begin(finalLink) {
  args.push('--', finalLink);
  const child = spawn(ytdlp, args, { windowsHide: true });
  job.current = child;
  let errors = '';
  let buffer = '';
  child.stdout.on('data', (chunk) => {
    buffer += chunk;
    const lines = buffer.split(/\r?\n/);
    buffer = lines.pop() ?? '';
    for (const line of lines) saveLine(line);
  });
  function saveLine(line) {
    try {
      const item = JSON.parse(line);
      if (item && typeof item.filepath === 'string') job.files.push(item);
    } catch {
      // Not a video line: ignore it.
    }
  }
  child.stderr.on('data', (chunk) => {
    errors += chunk;
  });
  child.on('error', (err) => {
    job.status = 'error';
    job.message = `Could not start yt-dlp: ${err.message}`;
  });
  child.on('close', async () => {
    if (buffer.trim()) saveLine(buffer);
    if (job.status === 'error') return;
    if (job.stopped) {
      removePartialFiles(outDir, startedAt);
      job.status = 'stopped';
      return;
    }
    if (job.files.length === 0) {
      job.status = 'error';
      job.message = errors.trim().split('\n').slice(-3).join(' ') || 'No video was saved.';
      if (/secondary user ID/i.test(errors)) {
        job.message = 'TikTok did not give the list of videos for this account. Paste the link of ONE video from this account, then press "Download all videos" again.';
      } else if (platform !== 'tiktok' && /log ?in|sign in|cookies|rate-limit|private|not available/i.test(errors)) {
        job.message += ' This site may need you to log in for this video, and this tool cannot log in.';
      }
      return;
    }
    if (withCaption && !ffmpeg) job.notes.push('The caption was not added, because ffmpeg was not found.');
    if (withCaption && ffmpeg) {
      job.stage = 'captioning';
      // Each video gets its own caption, taken from that same video.
      for (const item of job.files) {
        if (job.stopped) break;
        // YouTube descriptions are very long, so for YouTube the caption is the title.
        const text = String((platform === 'youtube' ? item.title : item.description || item.title) || '').trim();
        if (!text) {
          job.captioned += 1;
          continue;
        }
        try {
          await addCaption(job, item.filepath, text, Number(item.width) || 1080, Number(item.height) || 1920);
        } catch (err) {
          if (!job.stopped) job.notes.push(`The caption could not be added to one video: ${err.message}`);
        }
        job.captioned += 1;
      }
    }
    if (job.stopped) {
      removePartialFiles(outDir, startedAt);
      job.status = 'stopped';
      return;
    }
    job.stage = 'done';
    job.status = 'done';
  });
  }

  if (mode === 'all' && platform === 'tiktok' && isVideoLink(link)) {
    // "Download all videos" with the link of one video: find the account of that video first.
    job.stage = 'finding';
    findAccountId(job, link).then((accountId) => {
      if (job.stopped) {
        job.status = 'stopped';
      } else if (!accountId) {
        job.status = 'error';
        job.message = 'Could not find the account of this video. Check that the link works and the video is not private.';
      } else {
        job.stage = 'downloading';
        begin(`tiktokuser:${accountId}`);
      }
    });
  } else {
    begin(link);
  }
  return job;
}

function send(res, code, body) {
  res.writeHead(code, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

const server = http.createServer((req, res) => {
  if (req.method === 'OPTIONS') return send(res, 204, {});

  // A finished video, for a phone or another computer to save. The link holds the secret id of the
  // download (128 random bits), so it needs no code, and only finished videos can be fetched.
  const fileMatch = req.method === 'GET' && req.url?.match(/^\/file\/([0-9a-f-]{36})\/(\d+)$/);
  if (fileMatch) {
    const job = jobs.get(fileMatch[1]);
    const item = job?.status === 'done' ? job.files[Number(fileMatch[2])] : undefined;
    try {
      if (!item) throw new Error('no such video');
      const size = fs.statSync(item.filepath).size;
      const name = path.basename(item.filepath);
      res.writeHead(200, {
        'Content-Type': 'video/mp4',
        'Content-Length': size,
        'Content-Disposition': `attachment; filename="video-${Number(fileMatch[2]) + 1}.mp4"; filename*=UTF-8''${encodeURIComponent(name)}`,
      });
      return fs.createReadStream(item.filepath).pipe(res);
    } catch {
      return send(res, 404, { error: 'Video not found' });
    }
  }

  // Everything below needs to know who is asking: this computer, or another device with the code.
  const access = accessFor(req);
  const local = isLocal(req);

  // The page asks this when it opens, to know the helper is ready (and whether a code is needed).
  if (req.method === 'GET' && req.url === '/ping') {
    if (access === 'closed') return send(res, 403, { closed: true });
    if (access === 'locked') return send(res, 429, { locked: true });
    if (access === 'pin') return send(res, 401, { pin: true });
    return send(res, 200, { ok: true, folder: local ? defaultDir : '', remote: !local });
  }
  if (access === 'closed') return send(res, 403, { error: 'Not allowed' });
  if (access === 'locked') return send(res, 429, { error: 'Too many wrong codes. Try again in 10 minutes.' });
  if (access === 'pin') return send(res, 401, { error: 'A code is needed' });

  // The three requests below change things, so they need the special header.
  if (req.method === 'POST' && ['/download', '/open-folder', '/choose-folder', '/stop'].includes(req.url ?? '')) {
    if (req.headers[requiredHeader] !== '1') return send(res, 403, { error: 'Not allowed' });
    // Other devices cannot open windows on this computer.
    if (!local && (req.url === '/open-folder' || req.url === '/choose-folder')) return send(res, 403, { error: 'Only this computer can do that' });
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

      // The Stop button.
      if (req.url === '/stop') {
        const job = typeof data.id === 'string' ? jobs.get(data.id) : undefined;
        if (!job) return send(res, 404, { error: 'Unknown job' });
        stopJob(job);
        return send(res, 200, { ok: true });
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

      if (typeof data.link !== 'string' || !platformOf(data.link.trim())) return send(res, 400, { error: 'Not a supported link' });
      const quality = qualities.includes(String(data.quality)) ? String(data.quality) : 'best';
      // Another device cannot choose a folder: its videos go to the default folder of this computer.
      const job = startJob(data.link.trim(), data.mode === 'all' ? 'all' : 'one', quality, local ? resolveFolder(data.folder) : defaultDir, data.caption !== false);
      send(res, 200, { id: job.id });
    });
    return;
  }

  const match = req.method === 'GET' && req.url?.match(/^\/status\/([0-9a-f-]{36})$/);
  if (match) {
    const job = jobs.get(match[1]);
    if (!job) return send(res, 404, { error: 'Unknown job' });
    // The "p" number is the SHORT side of the picture, the way YouTube and TikTok name it:
    // a picture 1080 wide and 1440 tall is "1080p".
    const heights = [
      ...new Set(
        job.files
          .map((item) => (Number.isInteger(item.width) && Number.isInteger(item.height) ? Math.min(item.width, item.height) : item.height))
          .filter((h) => Number.isInteger(h)),
      ),
    ];
    return send(res, 200, {
      status: job.status,
      stage: job.stage,
      count: job.files.length,
      captioned: job.captioned,
      heights,
      notes: job.notes,
      message: job.message,
      folder: local ? job.folder : '',
      // The finished videos, so that a phone or another computer can save them itself.
      files: job.status === 'done' ? job.files.map((item, index) => ({ index, name: path.basename(item.filepath) })) : [],
    });
  }

  send(res, 404, { error: 'Not found' });
});

if (!fs.existsSync(ytdlp)) {
  console.error(`yt-dlp was not found at: ${ytdlp}`);
  console.error('Please double-click setup.bat first. It downloads the helper programs. Then start again.');
  process.exit(1);
}
fs.mkdirSync(defaultDir, { recursive: true });
server.listen(PORT, '127.0.0.1', () => {
  console.log(`Helper is ready on http://127.0.0.1:${PORT}`);
  console.log(`Videos are saved in: ${defaultDir} (unless you choose another folder on the page)`);
  console.log(ffmpeg ? `Captions on the video: ready (ffmpeg: ${ffmpeg})` : 'Captions on the video: NOT available (ffmpeg not found)');
});
