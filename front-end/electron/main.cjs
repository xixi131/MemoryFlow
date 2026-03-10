const { app, BrowserWindow, screen, ipcMain, Tray, Menu, shell, dialog } = require('electron');
const path = require('path');
const fs = require('fs');
const { pathToFileURL } = require('url');
const { startMusicListener, stopMusicListener } = require('./MusicService.cjs');
const { NsisUpdater } = require('electron-updater');

let widgetWindow;
let tray;
let pendingAuthData = null;
let pendingLogout = false;
const WIDGET_DISPLAY_MODE_KEY = 'widgetDisplayMode';

app.setName('MemoryFlow');
if (process.platform === 'win32') {
    app.setAppUserModelId('com.yourname.memoryflow');
}

// 配置路径
const configPath = path.join(app.getPath('userData'), 'app-config.json');

// 读取配置
function loadConfig() {
    try {
        if (fs.existsSync(configPath)) {
            return JSON.parse(fs.readFileSync(configPath, 'utf-8'));
        }
    } catch (e) {
        console.error('Failed to load config', e);
    }
    return null; // 首次运行
}

// 保存配置
function saveConfig(config) {
    try {
        fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
    } catch (e) {
        console.error('Failed to save config', e);
    }
}

function ensureDesktopShortcut() {
    if (process.platform !== 'win32') return;
    if (!app.isPackaged) return;

    try {
        const desktopDir = app.getPath('desktop');
        const shortcutPath = path.join(desktopDir, 'MemoryFlow.lnk');
        const options = {
            target: process.execPath,
            cwd: path.dirname(process.execPath),
            description: 'MemoryFlow',
            icon: process.execPath
        };

        if (fs.existsSync(shortcutPath)) {
            shell.writeShortcutLink(shortcutPath, 'update', options);
        } else {
            shell.writeShortcutLink(shortcutPath, 'create', options);
        }
    } catch (e) {
        console.error('[Shortcut] Failed to ensure desktop shortcut:', e?.message || e);
    }
}

function getConfigOrEmpty() {
    return loadConfig() || {};
}

function saveConfigPatch(patch) {
    const current = getConfigOrEmpty();
    const next = { ...current, ...patch };
    saveConfig(next);
    return next;
}

function getUpdaterConfig() {
    const config = getConfigOrEmpty();
    return config.updater || {};
}

function saveUpdaterConfig(patch) {
    const current = getConfigOrEmpty();
    const nextUpdater = { ...(current.updater || {}), ...patch };
    const next = { ...current, updater: nextUpdater };
    saveConfig(next);
    return nextUpdater;
}

function normalizeUpdateFeedUrl(value) {
    return String(value || '').trim().replace(/\/+$/, '');
}

function getUpdateFeedUrl() {
    const updaterConfig = getUpdaterConfig();
    return normalizeUpdateFeedUrl(
        process.env.MEMORYFLOW_UPDATE_URL
        || updaterConfig.feedUrl
        || 'https://update.memoryflow.tanxhub.com'
    );
}

function getReleaseNotesUrl() {
    return `${getUpdateFeedUrl()}/release-notes.json`;
}

// 初始化自启动设置
function initAutoLaunch() {
    if (!app.isPackaged) {
        return;
    }
    const config = loadConfig();
    const isFirstRun = config === null;

    if (isFirstRun) {
        console.log('First run detected, enabling auto-launch...');
        // 首次运行，默认开启
        app.setLoginItemSettings({
            openAtLogin: true,
            path: process.execPath
        });
        saveConfig({ autoLaunch: true });
    }
}

const UPDATE_STARTUP_DELAY_MS = 5000;
const UPDATE_THROTTLE_MS = 6 * 60 * 60 * 1000;
const UPDATE_REMIND_LATER_MS = 6 * 60 * 60 * 1000;

let updatePromptVisible = false;
let pendingManualUpdateCheck = false;
let updateProgressWindow = null;
let updateProgressWindowReady = false;
let updateCheckingWindow = null;
let updateCheckingTimeout = null;
let updateDownloadInProgress = false;
let updateErrorDialogVisible = false;
let autoUpdater = null;
let currentUpdateProgressState = {
    version: '',
    percent: 0,
    transferredText: '0 MB',
    totalText: '0 MB',
    speedText: '0 MB/s',
    statusText: '准备下载更新...'
};

function getUpdateLogPath() {
    try {
        return path.join(app.getPath('userData'), 'update-log.txt');
    } catch (e) {
        return null;
    }
}

function appendUpdateLog(event, extra = {}) {
    const logPath = getUpdateLogPath();
    if (!logPath) return;
    const payload = {
        time: new Date().toISOString(),
        event,
        ...extra
    };
    try {
        fs.appendFileSync(logPath, `${JSON.stringify(payload)}\n`);
    } catch (e) {
        // ignore logging failures
    }
}

function getAutoUpdater() {
    const feedUrl = getUpdateFeedUrl();
    if (!feedUrl) {
        return null;
    }

    if (!autoUpdater || autoUpdater.getFeedURL() !== feedUrl) {
        autoUpdater = new NsisUpdater({
            provider: 'generic',
            url: feedUrl
        });
        autoUpdater.autoDownload = false;
        autoUpdater.disableDifferentialDownload = true;
    }

    return autoUpdater;
}

function showMessageBox(options) {
    const win = widgetWindow && !widgetWindow.isDestroyed() ? widgetWindow : null;
    if (win) {
        return dialog.showMessageBox(win, options);
    }
    return dialog.showMessageBox(options);
}

function decodeHtmlEntities(value) {
    return String(value ?? '')
        .replace(/&nbsp;/gi, ' ')
        .replace(/&amp;/gi, '&')
        .replace(/&lt;/gi, '<')
        .replace(/&gt;/gi, '>')
        .replace(/&quot;/gi, '"')
        .replace(/&#39;/gi, "'");
}

function stripReleaseHtml(input) {
    if (!input) return '';
    const normalized = decodeHtmlEntities(String(input))
        .replace(/\r\n/g, '\n')
        .replace(/<br\s*\/?>/gi, '\n')
        .replace(/<\/p>/gi, '\n\n')
        .replace(/<\/div>/gi, '\n')
        .replace(/<\/li>/gi, '\n')
        .replace(/<li[^>]*>/gi, '• ')
        .replace(/<\/?(p|div|ul|ol)[^>]*>/gi, '\n')
        .replace(/<[^>]+>/g, '')
        .replace(/[ \t]+\n/g, '\n')
        .replace(/\n{3,}/g, '\n\n');
    return normalized.trim();
}

function formatBytes(bytes) {
    const size = Number(bytes || 0);
    if (!Number.isFinite(size) || size <= 0) return '0 MB';
    const units = ['B', 'KB', 'MB', 'GB'];
    let value = size;
    let unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
        value /= 1024;
        unitIndex += 1;
    }
    const digits = value >= 100 || unitIndex === 0 ? 0 : value >= 10 ? 1 : 2;
    return `${value.toFixed(digits)} ${units[unitIndex]}`;
}

function getUpdateProgressWindowHtml() {
    return `
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <title>MemoryFlow 更新</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f6f8fb;
      --card: rgba(255, 255, 255, 0.92);
      --text: #111827;
      --muted: #6b7280;
      --track: #e5e7eb;
      --fill: linear-gradient(90deg, #0ea5e9 0%, #2563eb 100%);
      --border: rgba(15, 23, 42, 0.08);
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "Microsoft YaHei UI", "PingFang SC", "Segoe UI", sans-serif;
      background: linear-gradient(180deg, #edf4ff 0%, var(--bg) 100%);
      color: var(--text);
    }
    .wrap {
      min-height: 100vh;
      padding: 20px;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .card {
      width: 100%;
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 18px;
      padding: 22px 22px 18px;
      box-shadow: 0 18px 40px rgba(15, 23, 42, 0.12);
      backdrop-filter: blur(10px);
    }
    .badge {
      width: 42px;
      height: 42px;
      border-radius: 14px;
      background: linear-gradient(135deg, #2563eb 0%, #0ea5e9 100%);
      color: white;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      font-size: 22px;
      font-weight: 700;
      box-shadow: 0 10px 24px rgba(37, 99, 235, 0.24);
    }
    .title {
      margin: 14px 0 6px;
      font-size: 22px;
      font-weight: 700;
      letter-spacing: 0.01em;
    }
    .subtitle {
      margin: 0;
      font-size: 14px;
      color: var(--muted);
      line-height: 1.6;
      min-height: 22px;
    }
    .progress-meta {
      margin-top: 18px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      font-size: 13px;
      color: var(--muted);
    }
    .progress-bar {
      margin-top: 10px;
      width: 100%;
      height: 10px;
      background: var(--track);
      border-radius: 999px;
      overflow: hidden;
    }
    .progress-fill {
      width: 0%;
      height: 100%;
      border-radius: inherit;
      background: var(--fill);
      transition: width 160ms ease-out;
    }
    .detail {
      margin-top: 12px;
      font-size: 13px;
      color: var(--muted);
      min-height: 20px;
    }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <div class="badge">↓</div>
      <div class="title" id="title">正在下载更新</div>
      <p class="subtitle" id="subtitle">准备下载更新...</p>
      <div class="progress-meta">
        <span id="status">准备下载更新...</span>
        <span id="percent">0%</span>
      </div>
      <div class="progress-bar">
        <div class="progress-fill" id="fill"></div>
      </div>
      <div class="detail" id="detail">已下载 0 MB / 0 MB</div>
    </div>
  </div>
  <script>
    window.renderUpdateProgress = function renderUpdateProgress(state) {
      const versionText = state.version ? (' v' + state.version) : '';
      document.getElementById('title').textContent = '正在下载更新' + versionText;
      document.getElementById('subtitle').textContent = '下载完成后将提示你重启安装。';
      document.getElementById('status').textContent = state.statusText || '正在下载更新...';
      document.getElementById('percent').textContent = (typeof state.percent === 'number' ? Math.round(state.percent) : 0) + '%';
      document.getElementById('fill').style.width = Math.max(0, Math.min(100, Number(state.percent || 0))) + '%';
      const speedText = state.speedText ? (' · ' + state.speedText) : '';
      document.getElementById('detail').textContent = '已下载 ' + (state.transferredText || '0 MB') + ' / ' + (state.totalText || '0 MB') + speedText;
    };
  </script>
</body>
</html>`;
}

function getUpdateCheckingWindowHtml() {
    return `
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <title>MemoryFlow 更新</title>
  <style>
    :root {
      color-scheme: light;
      --bg-1: #0f1b2d;
      --bg-2: #1b2c4a;
      --accent-blue: rgba(96, 165, 250, 0.35);
      --accent-pink: rgba(244, 114, 182, 0.28);
      --text: rgba(255, 255, 255, 0.92);
      --muted: rgba(226, 232, 240, 0.68);
    }
    * { box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
    }
    body {
      margin: 0;
      font-family: "Microsoft YaHei UI", "PingFang SC", "Segoe UI", sans-serif;
      background:
        radial-gradient(circle at 15% 20%, var(--accent-blue), transparent 45%),
        radial-gradient(circle at 85% 10%, var(--accent-pink), transparent 50%),
        linear-gradient(135deg, var(--bg-1) 0%, var(--bg-2) 100%);
      color: var(--text);
      position: relative;
    }
    .wrap {
      width: 100%;
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 14px;
    }
    .content {
      width: 100%;
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .orb {
      width: 14px;
      height: 14px;
      border-radius: 999px;
      border: 2px solid rgba(148, 163, 184, 0.35);
      border-top-color: rgba(96, 165, 250, 0.9);
      animation: spin 0.9s linear infinite;
    }
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
    .title {
      font-size: 16px;
      font-weight: 700;
      letter-spacing: 0.02em;
      color: var(--text);
    }
    .subtitle {
      font-size: 12px;
      color: var(--muted);
      margin-top: 4px;
      letter-spacing: 0.02em;
    }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="content">
      <div class="orb"></div>
      <div>
        <div class="title">正在检查更新…</div>
        <div class="subtitle">正在连接更新服务器</div>
      </div>
    </div>
  </div>
</body>
</html>`;
}

function createUpdateProgressWindow() {
    if (updateProgressWindow && !updateProgressWindow.isDestroyed()) {
        return updateProgressWindow;
    }

    const parent = widgetWindow && !widgetWindow.isDestroyed() ? widgetWindow : null;
    updateProgressWindowReady = false;
    updateProgressWindow = new BrowserWindow({
        width: 430,
        height: 250,
        show: false,
        resizable: false,
        minimizable: false,
        maximizable: false,
        fullscreenable: false,
        autoHideMenuBar: true,
        title: 'MemoryFlow 更新',
        parent: parent || undefined,
        modal: false,
        alwaysOnTop: true,
        backgroundColor: '#f6f8fb',
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            devTools: false
        }
    });

    updateProgressWindow.on('closed', () => {
        updateProgressWindow = null;
        updateProgressWindowReady = false;
    });

    updateProgressWindow.webContents.on('did-finish-load', () => {
        updateProgressWindowReady = true;
        pushUpdateProgressState(currentUpdateProgressState);
    });

    const html = getUpdateProgressWindowHtml();
    updateProgressWindow.loadURL(`data:text/html;charset=UTF-8,${encodeURIComponent(html)}`);
    return updateProgressWindow;
}

function createUpdateCheckingWindow() {
    if (updateCheckingWindow && !updateCheckingWindow.isDestroyed()) {
        return updateCheckingWindow;
    }

    const parent = widgetWindow && !widgetWindow.isDestroyed() ? widgetWindow : null;
    updateCheckingWindow = new BrowserWindow({
        width: 260,
        height: 120,
        show: false,
        resizable: false,
        minimizable: false,
        maximizable: false,
        fullscreenable: false,
        autoHideMenuBar: true,
        title: 'MemoryFlow 更新',
        parent: parent || undefined,
        modal: false,
        alwaysOnTop: true,
        backgroundColor: '#f8fafc',
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            devTools: false
        }
    });

    updateCheckingWindow.on('closed', () => {
        updateCheckingWindow = null;
    });

    const html = getUpdateCheckingWindowHtml();
    updateCheckingWindow.loadURL(`data:text/html;charset=UTF-8,${encodeURIComponent(html)}`);
    return updateCheckingWindow;
}

function showUpdateProgressWindow() {
    const win = createUpdateProgressWindow();
    if (win && !win.isDestroyed()) {
        if (!win.isVisible()) {
            win.show();
        }
        win.focus();
    }
}

function showUpdateCheckingWindow() {
    const win = createUpdateCheckingWindow();
    if (win && !win.isDestroyed()) {
        if (!win.isVisible()) {
            win.show();
        }
        win.focus();
    }
}

function closeUpdateProgressWindow() {
    if (updateProgressWindow && !updateProgressWindow.isDestroyed()) {
        updateProgressWindow.close();
    }
    updateProgressWindow = null;
    updateProgressWindowReady = false;
}

function closeUpdateCheckingWindow() {
    if (updateCheckingWindow && !updateCheckingWindow.isDestroyed()) {
        updateCheckingWindow.close();
    }
    updateCheckingWindow = null;
}

function clearUpdateCheckingTimeout() {
    if (updateCheckingTimeout) {
        clearTimeout(updateCheckingTimeout);
        updateCheckingTimeout = null;
    }
}

function pushUpdateProgressState(nextState) {
    currentUpdateProgressState = { ...currentUpdateProgressState, ...nextState };
    if (!updateProgressWindow || updateProgressWindow.isDestroyed() || !updateProgressWindowReady) {
        return;
    }
    const payload = JSON.stringify(currentUpdateProgressState);
    updateProgressWindow.webContents.executeJavaScript(
        `window.renderUpdateProgress && window.renderUpdateProgress(${payload});`,
        true
    ).catch(() => { });
}

async function showUpdaterErrorDialog({ message, detail }) {
    if (updateErrorDialogVisible) {
        return;
    }

    updateErrorDialogVisible = true;
    try {
        await showMessageBox({
            type: 'error',
            buttons: ['确定'],
            defaultId: 0,
            noLink: true,
            message,
            detail
        });
    } finally {
        updateErrorDialogVisible = false;
    }
}

function formatReleaseNotes(releaseNotes) {
    if (!releaseNotes) return '';
    if (typeof releaseNotes === 'string') return stripReleaseHtml(releaseNotes);
    if (Array.isArray(releaseNotes)) {
        return releaseNotes
            .map((n) => {
                const v = (n && typeof n === 'object') ? n.version : '';
                const note = (n && typeof n === 'object') ? stripReleaseHtml(n.note || '') : '';
                return [v ? `v${v}` : '', note].filter(Boolean).join('\n');
            })
            .filter(Boolean)
            .join('\n\n');
    }
    return '';
}

function normalizeReleaseNotesEntry(entry, version) {
    if (!entry || typeof entry !== 'object') {
        return null;
    }

    const rawVersion = entry.version != null ? String(entry.version) : version;
    if (version && rawVersion && rawVersion !== version) {
        return null;
    }

    const rawTitle = entry.title || entry.releaseName || entry.name || '';
    const rawNotes = entry.notes || entry.note || entry.description || entry.detail || '';
    const notes = Array.isArray(rawNotes)
        ? rawNotes.map((item) => stripReleaseHtml(item)).filter(Boolean).join('\n')
        : formatReleaseNotes(rawNotes);

    return {
        version: rawVersion || version || '',
        releaseName: rawTitle ? String(rawTitle) : '',
        releaseNotes: notes
    };
}

function normalizeReleaseNotesPayload(payload, version) {
    if (!payload) {
        return null;
    }

    if (Array.isArray(payload)) {
        for (const entry of payload) {
            const normalized = normalizeReleaseNotesEntry(entry, version);
            if (normalized) return normalized;
        }
        return null;
    }

    if (typeof payload !== 'object') {
        return null;
    }

    if (payload.versions && typeof payload.versions === 'object') {
        const versionEntry = payload.versions[version];
        const normalized = normalizeReleaseNotesEntry(versionEntry, version);
        if (normalized) return normalized;
    }

    if (payload.releases && typeof payload.releases === 'object') {
        const versionEntry = payload.releases[version];
        const normalized = normalizeReleaseNotesEntry(versionEntry, version);
        if (normalized) return normalized;
    }

    return normalizeReleaseNotesEntry(payload, version);
}

async function fetchSelfHostedReleaseNotes(version) {
    const requestUrl = getReleaseNotesUrl();
    if (!requestUrl || typeof fetch !== 'function') {
        return null;
    }

    const controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
    const timeoutId = controller ? setTimeout(() => controller.abort(), 3000) : null;

    try {
        const response = await fetch(requestUrl, {
            headers: {
                'Cache-Control': 'no-cache'
            },
            cache: 'no-store',
            signal: controller?.signal
        });

        if (!response.ok) {
            return null;
        }

        const payload = await response.json();
        return normalizeReleaseNotesPayload(payload, version);
    } catch (e) {
        console.warn('[Updater] Failed to fetch self-hosted release notes:', e?.message || e);
        return null;
    } finally {
        if (timeoutId) {
            clearTimeout(timeoutId);
        }
    }
}

async function preflightUpdateFeed() {
    const feedUrl = getUpdateFeedUrl();
    if (!feedUrl || typeof fetch !== 'function') {
        return { ok: false, message: 'no-feed' };
    }

    const latestUrl = `${feedUrl}/latest.yml`;
    const controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
    const timeoutId = controller ? setTimeout(() => controller.abort(), 4000) : null;

    try {
        const response = await fetch(latestUrl, {
            headers: { 'Cache-Control': 'no-cache' },
            cache: 'no-store',
            signal: controller?.signal
        });
        appendUpdateLog('preflight', { url: latestUrl, status: response.status, ok: response.ok });
        if (!response.ok) {
            return { ok: false, message: `HTTP ${response.status}` };
        }
        return { ok: true };
    } catch (e) {
        appendUpdateLog('preflight-error', { url: latestUrl, message: e?.message ? String(e.message) : 'unknown' });
        return { ok: false, message: e?.message ? String(e.message) : 'unknown' };
    } finally {
        if (timeoutId) clearTimeout(timeoutId);
    }
}

async function promptUpdateAvailable(updateInfo, manual) {
    if (!updateInfo || !updateInfo.version) return;
    if (updatePromptVisible) return;

    const updaterConfig = getUpdaterConfig();
    const isSkipped = updaterConfig.skipVersion && updaterConfig.skipVersion === updateInfo.version;
    if (!manual && isSkipped) return;

    updatePromptVisible = true;
    try {
        clearUpdateCheckingTimeout();
        closeUpdateCheckingWindow();
        const remoteNotes = await fetchSelfHostedReleaseNotes(updateInfo.version);
        const releaseName = remoteNotes?.releaseName || updateInfo.releaseName || '';
        const notes = remoteNotes?.releaseNotes || formatReleaseNotes(updateInfo.releaseNotes);
        const detailParts = [];
        if (releaseName) detailParts.push(String(releaseName));
        if (notes) detailParts.push(notes);

        const detail = detailParts.join('\n\n').slice(0, 3500);
        const { response } = await showMessageBox({
            type: 'info',
            buttons: ['稍后再说', '跳过此版本', '立即更新'],
            defaultId: 2,
            cancelId: 0,
            noLink: true,
            message: `发现新版本 v${updateInfo.version}`,
            detail: detail || '有新版本可用。'
        });

        if (response === 0) {
            saveUpdaterConfig({ remindLaterUntil: Date.now() + UPDATE_REMIND_LATER_MS });
            return;
        }

        if (response === 1) {
            saveUpdaterConfig({ skipVersion: updateInfo.version, remindLaterUntil: 0 });
            return;
        }

        if (response === 2) {
            try {
                const updater = getAutoUpdater();
                if (!updater) {
                    await showUpdaterErrorDialog({
                        message: '未配置更新源',
                        detail: '请先配置 updater.feedUrl 或环境变量 MEMORYFLOW_UPDATE_URL。'
                    });
                    return;
                }
                updateDownloadInProgress = true;
                pushUpdateProgressState({
                    version: updateInfo.version,
                    percent: 0,
                    transferredText: '0 MB',
                    totalText: '0 MB',
                    speedText: '0 MB/s',
                    statusText: '开始下载更新...'
                });
                showUpdateProgressWindow();
                await updater.downloadUpdate();
            } catch (e) {
                updateDownloadInProgress = false;
                closeUpdateProgressWindow();
                await showUpdaterErrorDialog({
                    message: '下载更新失败',
                    detail: e?.message ? String(e.message) : '请稍后重试。'
                });
            }
        }
    } finally {
        updatePromptVisible = false;
    }
}

async function promptUpdateDownloaded() {
    closeUpdateProgressWindow();
    const { response } = await showMessageBox({
        type: 'info',
        buttons: ['稍后', '重启安装'],
        defaultId: 1,
        cancelId: 0,
        noLink: true,
        message: '更新已下载完成',
        detail: '点击“重启安装”将退出并安装更新。'
    });

    if (response === 1) {
        const updater = getAutoUpdater();
        if (updater) {
            updater.quitAndInstall();
        }
    }
}

async function checkForUpdates({ manual, force } = { manual: false, force: false }) {
    if (!app.isPackaged) {
        if (manual) {
            showUpdateCheckingWindow();
            setTimeout(() => closeUpdateCheckingWindow(), 200);
            await showMessageBox({
                type: 'info',
                buttons: ['确定'],
                defaultId: 0,
                noLink: true,
                message: '开发环境不检查更新',
                detail: '请打包后在安装版应用中测试自动更新。'
            });
        }
        return;
    }

    const updater = getAutoUpdater();
    if (!updater) {
        if (manual) {
            showUpdateCheckingWindow();
            setTimeout(() => closeUpdateCheckingWindow(), 200);
            await showMessageBox({
                type: 'warning',
                buttons: ['确定'],
                defaultId: 0,
                noLink: true,
                message: '未配置更新源',
                detail: '请先配置 updater.feedUrl 或环境变量 MEMORYFLOW_UPDATE_URL。'
            });
        }
        return;
    }

    const updaterConfig = getUpdaterConfig();
    if (!manual) {
        if (updaterConfig.remindLaterUntil && Date.now() < updaterConfig.remindLaterUntil) return;
        if (!force && updaterConfig.lastCheckTime && Date.now() - updaterConfig.lastCheckTime < UPDATE_THROTTLE_MS) return;
    }

    if (manual) {
        showUpdateCheckingWindow();
        clearUpdateCheckingTimeout();
        updateCheckingTimeout = setTimeout(() => {
            if (pendingManualUpdateCheck) {
                pendingManualUpdateCheck = false;
                closeUpdateCheckingWindow();
                appendUpdateLog('check-timeout', { feedUrl: getUpdateFeedUrl() });
                showMessageBox({
                    type: 'warning',
                    buttons: ['确定'],
                    defaultId: 0,
                    noLink: true,
                    message: '检查更新超时',
                    detail: '请检查网络或更新源是否可用。'
                }).catch(() => { });
            }
        }, 15000);
    }
    saveUpdaterConfig({ lastCheckTime: Date.now() });
    try {
        appendUpdateLog('check-start', { manual, feedUrl: getUpdateFeedUrl() });
        const preflight = await preflightUpdateFeed();
        if (!preflight.ok) {
            clearUpdateCheckingTimeout();
            closeUpdateCheckingWindow();
            if (manual) {
                await showMessageBox({
                    type: 'warning',
                    buttons: ['确定'],
                    defaultId: 0,
                    noLink: true,
                    message: '更新源不可用',
                    detail: preflight.message || '无法访问更新源，请检查网络或证书。'
                });
            }
            return;
        }
        pendingManualUpdateCheck = !!manual;
        await updater.checkForUpdates();
    } catch (e) {
        appendUpdateLog('check-error', { message: e?.message ? String(e.message) : 'unknown' });
        clearUpdateCheckingTimeout();
        closeUpdateCheckingWindow();
        pendingManualUpdateCheck = false;
        if (manual) {
            await showMessageBox({
                type: 'error',
                buttons: ['确定'],
                defaultId: 0,
                noLink: true,
                message: '检查更新失败',
                detail: e?.message ? String(e.message) : '请稍后重试。'
            });
        }
    }
}

function initUpdater() {
    const updater = getAutoUpdater();
    if (!updater) {
        return;
    }

    updater.removeAllListeners('update-available');
    updater.removeAllListeners('update-not-available');
    updater.removeAllListeners('update-downloaded');
    updater.removeAllListeners('download-progress');
    updater.removeAllListeners('error');

    updater.on('update-available', async (info) => {
        appendUpdateLog('update-available', { version: info?.version || '' });
        const manual = pendingManualUpdateCheck;
        pendingManualUpdateCheck = false;
        await promptUpdateAvailable(info, manual);
    });

    updater.on('checking-for-update', () => {
        appendUpdateLog('checking-for-update', { feedUrl: getUpdateFeedUrl() });
    });

    updater.on('update-not-available', async () => {
        if (pendingManualUpdateCheck) {
            pendingManualUpdateCheck = false;
            clearUpdateCheckingTimeout();
            closeUpdateCheckingWindow();
            appendUpdateLog('update-not-available', { version: app.getVersion() });
            await showMessageBox({
                type: 'info',
                buttons: ['确定'],
                defaultId: 0,
                noLink: true,
                message: '当前已是最新版本',
                detail: `版本：v${app.getVersion()}`
            });
        }
    });

    updater.on('update-downloaded', async () => {
        appendUpdateLog('update-downloaded', {});
        clearUpdateCheckingTimeout();
        closeUpdateCheckingWindow();
        try {
            updateDownloadInProgress = false;
            if (widgetWindow && !widgetWindow.isDestroyed()) {
                widgetWindow.setProgressBar(-1);
            }
            if (tray) {
                tray.setToolTip('MemoryFlow Widget');
            }
        } catch (e) { }
        await promptUpdateDownloaded();
    });

    updater.on('download-progress', (progress) => {
        try {
            const percent = typeof progress?.percent === 'number' ? progress.percent : 0;
            const normalized = Math.max(0, Math.min(100, percent));
            updateDownloadInProgress = true;
            if (widgetWindow && !widgetWindow.isDestroyed()) {
                widgetWindow.setProgressBar(normalized / 100);
            }
            if (tray) {
                tray.setToolTip(`MemoryFlow Widget（正在下载更新 ${normalized.toFixed(0)}%）`);
            }
            pushUpdateProgressState({
                percent: normalized,
                transferredText: formatBytes(progress?.transferred),
                totalText: formatBytes(progress?.total),
                speedText: formatBytes(progress?.bytesPerSecond) + '/s',
                statusText: `正在下载更新 ${normalized.toFixed(0)}%`
            });
        } catch (e) { }
    });

    updater.on('error', async (err) => {
        const hadDownloadInProgress = updateDownloadInProgress;
        const shouldShowError = pendingManualUpdateCheck || updatePromptVisible || hadDownloadInProgress;
        try {
            updateDownloadInProgress = false;
            appendUpdateLog('update-error', { message: err?.message ? String(err.message) : 'unknown' });
            clearUpdateCheckingTimeout();
            closeUpdateCheckingWindow();
            if (widgetWindow && !widgetWindow.isDestroyed()) {
                widgetWindow.setProgressBar(-1);
            }
            if (tray) {
                tray.setToolTip('MemoryFlow Widget');
            }
            if (hadDownloadInProgress) {
                closeUpdateProgressWindow();
            }
        } catch (e) { }
        if (pendingManualUpdateCheck) {
            pendingManualUpdateCheck = false;
            await showUpdaterErrorDialog({
                message: '更新发生错误',
                detail: err?.message ? String(err.message) : '请稍后重试。'
            });
        } else if (shouldShowError) {
            await showUpdaterErrorDialog({
                message: '更新发生错误',
                detail: err?.message ? String(err.message) : '请稍后重试。'
            });
        }
    });

    setTimeout(() => {
        checkForUpdates({ manual: false, force: true });
    }, UPDATE_STARTUP_DELAY_MS);
}

// 协议注册 (Protocol Registration)
if (process.defaultApp) {
    if (process.argv.length >= 2) {
        app.setAsDefaultProtocolClient('memoryflow', process.execPath, [path.resolve(process.argv[1])]);
    }
} else {
    app.setAsDefaultProtocolClient('memoryflow');
}

// 单实例锁 (Single Instance Lock)
const gotTheLock = app.requestSingleInstanceLock();
console.log('Got single instance lock:', gotTheLock);

if (!gotTheLock) {
    console.log('Quitting because another instance is running');
    app.quit();
} else {
    app.on('second-instance', (event, commandLine, workingDirectory) => {
        // 当运行第二个实例时，聚焦到当前窗口
        if (widgetWindow) {
            if (!widgetWindow.isVisible()) widgetWindow.show();
            if (widgetWindow.isMinimized()) widgetWindow.restore();
            widgetWindow.focus();
        }

        // Windows 平台处理 Deep Link
        const url = commandLine.find(arg => arg.startsWith('memoryflow://'));
        if (url) handleDeepLink(url);
    });

    app.whenReady().then(() => {
        console.log('App is ready, creating window...');
        initAutoLaunch();
        createWidgetWindow();
        createTray();
        initUpdater();
        ensureDesktopShortcut();

        // Start music listener after window is created
        startMusicListener(widgetWindow);

        const initialUrl = process.argv.find(arg => arg.startsWith('memoryflow://'));
        if (initialUrl) handleDeepLink(initialUrl);

        app.on('activate', () => {
            if (BrowserWindow.getAllWindows().length === 0) createWidgetWindow();
        });
    }).catch(err => console.error('Error during app ready:', err));
}

// macOS 平台处理 Deep Link
app.on('open-url', (event, url) => {
    event.preventDefault();
    handleDeepLink(url);
});

// 处理 Deep Link URL
function handleDeepLink(url) {
    console.log('Deep link received:', url);
    try {
        const urlObj = new URL(url);
        const token = urlObj.searchParams.get('token');
        const refreshToken = urlObj.searchParams.get('refreshToken');
        const expiresInRaw = urlObj.searchParams.get('expiresIn');
        const expiresIn = expiresInRaw ? Number(expiresInRaw) : undefined;
        if (token) {
            sendTokenToRenderer({ accessToken: token, refreshToken: refreshToken || undefined, expiresIn });
        }
    } catch (error) {
        console.error('Error parsing deep link:', error);
    }
}

function sendTokenToRenderer(authData) {
    pendingAuthData = authData;
    if (!widgetWindow || widgetWindow.isDestroyed()) {
        return;
    }

    const deliver = () => {
        if (!widgetWindow || widgetWindow.isDestroyed()) {
            return;
        }
        widgetWindow.webContents.send('auth-token', authData);
        widgetWindow.show();
        pendingAuthData = null;
    };

    if (widgetWindow.webContents.isLoading()) {
        widgetWindow.webContents.once('did-finish-load', deliver);
    } else {
        deliver();
    }
}

function sendLogoutToRenderer() {
    pendingLogout = true;
    pendingAuthData = null;

    if (!widgetWindow || widgetWindow.isDestroyed()) {
        return;
    }

    const deliver = () => {
        if (!widgetWindow || widgetWindow.isDestroyed()) {
            return;
        }
        widgetWindow.webContents.send('auth-logout');
        widgetWindow.show();
        pendingLogout = false;
    };

    if (widgetWindow.webContents.isLoading()) {
        widgetWindow.webContents.once('did-finish-load', deliver);
    } else {
        deliver();
    }
}

function getWidgetDisplayMode() {
    const config = getConfigOrEmpty();
    const mode = config[WIDGET_DISPLAY_MODE_KEY];
    return mode === 'todo' ? 'todo' : 'review';
}

function sendWidgetDisplayModeToRenderer(targetWebContents) {
    const webContents = targetWebContents || (widgetWindow && !widgetWindow.isDestroyed() ? widgetWindow.webContents : null);
    if (!webContents || webContents.isDestroyed()) {
        return;
    }
    webContents.send('widget-display-mode-changed', getWidgetDisplayMode());
}

function setWidgetDisplayMode(mode) {
    const normalizedMode = mode === 'todo' ? 'todo' : 'review';
    saveConfigPatch({ [WIDGET_DISPLAY_MODE_KEY]: normalizedMode });
    sendWidgetDisplayModeToRenderer();
    refreshTrayMenu();
}

function refreshTrayMenu() {
    if (!tray) return;

    const currentMode = getWidgetDisplayMode();
    const isAutoLaunch = app.isPackaged ? app.getLoginItemSettings().openAtLogin : false;

    const contextMenu = Menu.buildFromTemplate([
        {
            label: '显示/隐藏悬浮窗',
            click: () => {
                if (widgetWindow.isVisible()) {
                    widgetWindow.hide();
                } else {
                    widgetWindow.show();
                }
            }
        },
        {
            label: '显示模式',
            submenu: [
                {
                    label: '复习模式',
                    type: 'radio',
                    checked: currentMode === 'review',
                    click: () => setWidgetDisplayMode('review')
                },
                {
                    label: '待办模式',
                    type: 'radio',
                    checked: currentMode === 'todo',
                    click: () => setWidgetDisplayMode('todo')
                }
            ]
        },
        {
            label: '开机自动启动',
            type: 'checkbox',
            checked: isAutoLaunch,
            enabled: app.isPackaged,
            click: (menuItem) => {
                const newState = menuItem.checked;
                app.setLoginItemSettings({
                    openAtLogin: newState,
                    path: process.execPath
                });
                // 更新本地配置，保持同步
                saveConfigPatch({ autoLaunch: newState });
            }
        },
        {
            label: '访问官网',
            click: () => {
                shell.openExternal('https://memoryflow.tanxhub.com');
            }
        },
        {
            label: '检查更新',
            click: () => {
                checkForUpdates({ manual: true });
            }
        },
        {
            label: '退出登录',
            click: () => {
                sendLogoutToRenderer();
            }
        },
        { type: 'separator' },
        {
            label: '退出',
            click: () => {
                app.quit();
            }
        }
    ]);

    tray.setToolTip('MemoryFlow Widget');
    tray.setContextMenu(contextMenu);
}

// 创建系统托盘
function createTray() {
    let iconPath;
    if (!app.isPackaged && process.env.ELECTRON_START_URL) {
        // 开发环境：直接引用 src 下的资源
        iconPath = path.join(__dirname, '../src/assets/logo.png');
    } else {
        // 生产环境：引用复制到 electron/assets 下的资源
        iconPath = path.join(__dirname, 'assets/logo.png');
    }

    tray = new Tray(iconPath);
    refreshTrayMenu();

    tray.on('click', () => {
        if (widgetWindow.isVisible()) {
            widgetWindow.hide();
        } else {
            widgetWindow.show();
        }
    });
}

function createWidgetWindow() {
    const positionWindow = (width, height) => {
        try {
            const { width: screenWidth } = screen.getPrimaryDisplay().workAreaSize;
            const x = Math.max(0, Math.floor(((screenWidth || 0) - width) / 2));
            widgetWindow.setBounds({ x, y: 0, width, height });
        } catch (e) { }
    };

    // 使用固定的最大尺寸，避免动画时的窗口调整导致闪烁
    const initialWidth = 620; 
    const initialHeight = 300;

    // Create the browser window.
    widgetWindow = new BrowserWindow({
        width: initialWidth,
        height: initialHeight, 
        x: 0,
        y: 0, // Stick to top edge
        show: false,
        frame: false, // Frameless
        transparent: true, // Transparent background
        alwaysOnTop: false, // Do NOT force on top to avoid blocking other apps
        skipTaskbar: true, // Don't show in taskbar
        resizable: false, // Prevent manual resizing
        hasShadow: false,
        backgroundColor: '#00000000', // Ensure transparent background
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false,
            devTools: true,
            webSecurity: false // Allow loading local resources if needed
        },
    });

    positionWindow(initialWidth, initialHeight);

    // Handle Ignore Mouse Events
    ipcMain.on('set-ignore-mouse-events', (event, ignore, options) => {
        const win = BrowserWindow.fromWebContents(event.sender);
        if (win) {
            win.setIgnoreMouseEvents(ignore, options);
        }
    });

    // 监听调整窗口大小
    ipcMain.on('resize-widget', (event, { width, height }) => {
        if (widgetWindow) {
            // 保持 y = 0，更新宽度和高度，并水平居中
            positionWindow(width, height);
        }
    });

    ipcMain.removeAllListeners('get-widget-display-mode');
    ipcMain.on('get-widget-display-mode', (event) => {
        try {
            sendWidgetDisplayModeToRenderer(event.sender);
        } catch (e) { }
    });

    ipcMain.removeAllListeners('set-widget-display-mode');
    ipcMain.on('set-widget-display-mode', (_event, mode) => {
        try {
            setWidgetDisplayMode(mode === 'todo' ? 'todo' : 'review');
        } catch (e) { }
    });

    // Load the app
    // In production, we need to load the index.html and handle the hash route manually if needed, 
    // or ensure the app handles the default route correctly.

    if (!app.isPackaged && process.env.ELECTRON_START_URL) {
        widgetWindow.loadURL(process.env.ELECTRON_START_URL + '#/widget');
    } else {
        // For production (file:// protocol), use loadFile which handles paths correctly on Windows
        const indexPath = path.join(__dirname, '../dist/index.html');
        // Load file directly with hash is tricky in Electron loadFile, using loadURL with file protocol is safer for hash
        const fileUrl = pathToFileURL(indexPath).toString();
        widgetWindow.loadURL(`${fileUrl}#/widget`);
    }

    widgetWindow.once('ready-to-show', () => {
        try {
            positionWindow(initialWidth, initialHeight);
            widgetWindow.show();
        } catch (e) { }

        setTimeout(() => {
            try {
                if (widgetWindow && !widgetWindow.isDestroyed()) {
                    positionWindow(initialWidth, initialHeight);
                }
            } catch (e) { }
        }, 1500);
    });

    screen.on('display-metrics-changed', () => {
        try {
            if (widgetWindow && !widgetWindow.isDestroyed()) {
                const bounds = widgetWindow.getBounds();
                positionWindow(bounds.width, bounds.height);
            }
        } catch (e) { }
    });

    widgetWindow.webContents.on('did-finish-load', () => {
        sendWidgetDisplayModeToRenderer(widgetWindow.webContents);
        if (pendingAuthData) {
            sendTokenToRenderer(pendingAuthData);
        }
        if (pendingLogout) {
            sendLogoutToRenderer();
        }
    });

    widgetWindow.on('blur', () => {
        try {
            if (widgetWindow && !widgetWindow.isDestroyed()) {
                widgetWindow.webContents.send('widget-collapse');
            }
        } catch (e) { }
    });

    // Open DevTools in dev mode
    // widgetWindow.webContents.openDevTools({ mode: 'detach' });
}

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
});

app.on('before-quit', () => {
    stopMusicListener();
});
