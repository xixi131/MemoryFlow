const { ipcMain } = require('electron');
const { Worker } = require('worker_threads');
const path = require('path');
const { exec } = require('child_process');

let worker = null;

// 发送媒体按键 (使用 Base64 编码的 PowerShell 脚本避免编码问题)
// VK_MEDIA_NEXT_TRACK = 0xB0 = 176, VK_MEDIA_PREV_TRACK = 0xB1 = 177, VK_MEDIA_PLAY_PAUSE = 0xB3 = 179
const sendMediaKey = (vkCode) => {
    try {
        // 创建 PowerShell 脚本
        const script = `
$code = @"
using System;
using System.Runtime.InteropServices;
public class MediaKeys {
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
}
"@
Add-Type -TypeDefinition $code -Language CSharp -ErrorAction SilentlyContinue
[MediaKeys]::keybd_event(${vkCode}, 0, 0, [UIntPtr]::Zero)
[MediaKeys]::keybd_event(${vkCode}, 0, 2, [UIntPtr]::Zero)
`;
        // 将脚本转为 UTF-16LE Base64 (PowerShell -EncodedCommand 需要的格式)
        const base64 = Buffer.from(script, 'utf16le').toString('base64');

        exec(`powershell -NoProfile -NonInteractive -EncodedCommand ${base64}`, { windowsHide: true }, (error) => {
            if (error) {
                console.error('[MusicService] MediaKey exec failed:', error.message);
            } else {
                console.log('[MusicService] MediaKey sent successfully:', vkCode);
            }
        });
    } catch (e) {
        console.error('[MusicService] MediaKey execution error:', e);
    }
};

function startMusicListener(mainWindow) {
    if (worker) return;

    const workerPath = path.join(__dirname, 'MusicWorker.cjs');
    console.log('[MusicService] Starting Worker thread:', workerPath);

    try {
        worker = new Worker(workerPath);

        worker.on('message', (message) => {
            if (message.type === 'log') {
                console.log('[MusicWorker]', message.data);
            } else if (message.type === 'error') {
                console.error('[MusicWorker Error]', message.data);
            } else if (message.type === 'music-data') {
                if (mainWindow && !mainWindow.isDestroyed()) {
                    mainWindow.webContents.send('music-data-update', message.data);
                }
            }
        });

        worker.on('error', (err) => {
            console.error('[MusicService] Worker error:', err);
            // Restart worker on crash
            worker = null;
            setTimeout(() => startMusicListener(mainWindow), 5000);
        });

        worker.on('exit', (code) => {
            if (code !== 0) console.error(`[MusicService] Worker stopped with exit code ${code}`);
            worker = null;
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
}

module.exports = { startMusicListener, stopMusicListener };
