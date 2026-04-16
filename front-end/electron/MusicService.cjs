const { ipcMain } = require('electron');
const { Worker } = require('worker_threads');
const path = require('path');
const { execFile, spawn } = require('child_process');

let worker = null;
let mediaKeyProcess = null;
let mediaKeyChannelReady = false;
let mediaKeyChannelStarting = false;
let mediaKeyStdoutBuffer = '';
let lastForwardedMusicData = null;

const POWERSHELL_EXECUTABLE = process.platform === 'win32' ? 'powershell.exe' : 'powershell';
const MEDIA_CHANNEL_READY_TOKEN = '__MF_MEDIA_KEY_READY__';

const MEDIA_KEY_SCRIPT_TEMPLATE = `
$code = @"
using System;
using System.Runtime.InteropServices;
public class MediaKeys {
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
}
"@
Add-Type -TypeDefinition $code -Language CSharp -ErrorAction SilentlyContinue
[MediaKeys]::keybd_event({VK_CODE}, 0, 0, [UIntPtr]::Zero)
[MediaKeys]::keybd_event({VK_CODE}, 0, 2, [UIntPtr]::Zero)
`;

function getEncodedMediaKeyCommand(vkCode) {
    const script = MEDIA_KEY_SCRIPT_TEMPLATE.split('{VK_CODE}').join(String(vkCode));
    return Buffer.from(script, 'utf16le').toString('base64');
}

function createMediaChannelBootstrapScript() {
    return `
$ErrorActionPreference = 'Stop'
$code = @"
using System;
using System.Runtime.InteropServices;
public class MediaKeys {
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
}
"@
Add-Type -TypeDefinition $code -Language CSharp -ErrorAction SilentlyContinue
function Send-MediaKey([int]$vkCode) {
    [MediaKeys]::keybd_event([byte]$vkCode, 0, 0, [UIntPtr]::Zero)
    [MediaKeys]::keybd_event([byte]$vkCode, 0, 2, [UIntPtr]::Zero)
}
Write-Output '${MEDIA_CHANNEL_READY_TOKEN}'
`;
}

function resetMediaKeyChannelState() {
    mediaKeyProcess = null;
    mediaKeyChannelReady = false;
    mediaKeyChannelStarting = false;
    mediaKeyStdoutBuffer = '';
}

function stopMediaKeyChannel() {
    if (mediaKeyProcess && !mediaKeyProcess.killed) {
        try {
            if (mediaKeyProcess.stdin && !mediaKeyProcess.stdin.destroyed) {
                mediaKeyProcess.stdin.end();
            }
        } catch (e) { }
        try {
            mediaKeyProcess.kill();
        } catch (e) { }
    }
    resetMediaKeyChannelState();
}

function ensureMediaKeyChannel() {
    if (process.platform !== 'win32') return;
    if (mediaKeyProcess && !mediaKeyProcess.killed) return;
    if (mediaKeyChannelStarting) return;

    mediaKeyChannelStarting = true;
    mediaKeyChannelReady = false;
    mediaKeyStdoutBuffer = '';

    try {
        const child = spawn(
            POWERSHELL_EXECUTABLE,
            ['-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', '-'],
            { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] }
        );

        mediaKeyProcess = child;
        child.stdout.setEncoding('utf8');
        child.stderr.setEncoding('utf8');

        child.stdout.on('data', (chunk) => {
            mediaKeyStdoutBuffer += chunk;
            if (mediaKeyStdoutBuffer.includes(MEDIA_CHANNEL_READY_TOKEN)) {
                mediaKeyChannelReady = true;
                mediaKeyChannelStarting = false;
                mediaKeyStdoutBuffer = '';
            }
        });

        child.stderr.on('data', (chunk) => {
            const text = String(chunk || '').trim();
            if (text) {
                console.warn('[MusicService] MediaKey channel stderr:', text);
            }
        });

        child.on('error', (error) => {
            console.error('[MusicService] MediaKey channel error:', error?.message || error);
            resetMediaKeyChannelState();
        });

        child.on('exit', (code, signal) => {
            if (code !== 0 && signal !== 'SIGTERM') {
                console.warn(`[MusicService] MediaKey channel exited (code=${code}, signal=${signal || 'none'})`);
            }
            resetMediaKeyChannelState();
        });

        child.stdin.write(createMediaChannelBootstrapScript() + '\n');
    } catch (error) {
        console.error('[MusicService] Failed to start MediaKey channel:', error?.message || error);
        resetMediaKeyChannelState();
    }
}

function sendMediaKeyViaFallback(vkCode) {
    try {
        const encoded = getEncodedMediaKeyCommand(vkCode);
        execFile(
            POWERSHELL_EXECUTABLE,
            ['-NoProfile', '-NonInteractive', '-EncodedCommand', encoded],
            { windowsHide: true },
            (error) => {
                if (error) {
                    console.error('[MusicService] MediaKey fallback failed:', error.message);
                }
            }
        );
    } catch (e) {
        console.error('[MusicService] MediaKey fallback error:', e);
    }
}

function writeMediaKeyToChannel(vkCode) {
    if (!mediaKeyProcess || mediaKeyProcess.killed) return false;
    if (!mediaKeyChannelReady) return false;
    if (!mediaKeyProcess.stdin || mediaKeyProcess.stdin.destroyed || !mediaKeyProcess.stdin.writable) return false;
    try {
        mediaKeyProcess.stdin.write(`Send-MediaKey ${vkCode}\n`);
        return true;
    } catch (e) {
        return false;
    }
}

function shouldForwardMusicData(nextData) {
    if (!nextData || typeof nextData !== 'object') return false;
    if (!lastForwardedMusicData) return true;

    const prev = lastForwardedMusicData;
    if (nextData.status !== prev.status) return true;
    if (nextData.isPlaying !== prev.isPlaying) return true;
    if (nextData.title !== prev.title) return true;
    if (nextData.artist !== prev.artist) return true;
    if (nextData.coverUrl !== prev.coverUrl) return true;
    if (nextData.themeColor !== prev.themeColor) return true;
    if (Number(nextData.duration || 0) !== Number(prev.duration || 0)) return true;

    const nextPos = Number(nextData.position || 0);
    const prevPos = Number(prev.position || 0);
    if (Math.abs(nextPos - prevPos) >= 1) return true;

    return false;
}

// 发送媒体按键 (使用 Base64 编码的 PowerShell 脚本避免编码问题)
// VK_MEDIA_NEXT_TRACK = 0xB0 = 176, VK_MEDIA_PREV_TRACK = 0xB1 = 177, VK_MEDIA_PLAY_PAUSE = 0xB3 = 179
const sendMediaKey = (vkCode) => {
    if (process.platform !== 'win32') return;
    ensureMediaKeyChannel();
    if (writeMediaKeyToChannel(vkCode)) return;
    // Channel may still be warming up; fallback keeps first-click responsiveness.
    sendMediaKeyViaFallback(vkCode);
};

function startMusicListener(mainWindow) {
    if (worker) return;

    const workerPath = path.join(__dirname, 'MusicWorker.cjs');
    console.log('[MusicService] Starting Worker thread:', workerPath);

    try {
        worker = new Worker(workerPath);
        lastForwardedMusicData = null;
        ensureMediaKeyChannel();

        worker.on('message', (message) => {
            if (message.type === 'log') {
                console.log('[MusicWorker]', message.data);
            } else if (message.type === 'error') {
                console.error('[MusicWorker Error]', message.data);
            } else if (message.type === 'music-data') {
                if (!shouldForwardMusicData(message.data)) {
                    return;
                }
                lastForwardedMusicData = { ...message.data };
                if (mainWindow && !mainWindow.isDestroyed()) {
                    mainWindow.webContents.send('music-data-update', message.data);
                }
            }
        });

        worker.on('error', (err) => {
            console.error('[MusicService] Worker error:', err);
            // Restart worker on crash
            worker = null;
            lastForwardedMusicData = null;
            setTimeout(() => startMusicListener(mainWindow), 5000);
        });

        worker.on('exit', (code) => {
            if (code !== 0) console.error(`[MusicService] Worker stopped with exit code ${code}`);
            worker = null;
            lastForwardedMusicData = null;
        });

    } catch (e) {
        console.error('[MusicService] Failed to create worker:', e);
    }

    // 注册控制监听 (只需注册一次)
    ipcMain.removeAllListeners('media-control');
    ipcMain.on('media-control', (event, command) => {
        console.log('[MusicService] 收到控制指令:', command);
        // VK_MEDIA_PLAY_PAUSE = 0xB3 = 179
        // VK_MEDIA_PREV_TRACK = 0xB1 = 177
        // VK_MEDIA_NEXT_TRACK = 0xB0 = 176
        switch (command) {
            case 'play-pause': sendMediaKey(179); break;
            case 'prev': sendMediaKey(177); break;
            case 'next': sendMediaKey(176); break;
        }
    });

    // 注册 seek 监听
    ipcMain.removeAllListeners('media-seek');
    ipcMain.on('media-seek', (event, position) => {
        console.log('[MusicService] 收到 seek 指令:', position, '秒');
        // 发送给 worker 尝试 SMTC seek
        if (worker) {
            worker.postMessage({ type: 'seek', position });
        }
    });
}

function stopMusicListener() {
    if (worker) {
        worker.terminate();
        worker = null;
    }
    lastForwardedMusicData = null;
    stopMediaKeyChannel();
}

module.exports = { startMusicListener, stopMusicListener };
