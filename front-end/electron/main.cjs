const { app, BrowserWindow, screen, ipcMain, Tray, Menu, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const { startMusicListener, stopMusicListener } = require('./MusicService.cjs');

let widgetWindow;
let tray;
let pendingAuthToken = null;
let pendingLogout = false;

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
        if (token) {
            sendTokenToRenderer(token);
        }
    } catch (error) {
        console.error('Error parsing deep link:', error);
    }
}

function sendTokenToRenderer(token) {
    pendingAuthToken = token;
    if (!widgetWindow || widgetWindow.isDestroyed()) {
        return;
    }

    const deliver = () => {
        if (!widgetWindow || widgetWindow.isDestroyed()) {
            return;
        }
        widgetWindow.webContents.send('auth-token', token);
        widgetWindow.show();
        pendingAuthToken = null;
    };

    if (widgetWindow.webContents.isLoading()) {
        widgetWindow.webContents.once('did-finish-load', deliver);
    } else {
        deliver();
    }
}

function sendLogoutToRenderer() {
    pendingLogout = true;
    pendingAuthToken = null;

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

// 创建系统托盘
function createTray() {
    let iconPath;
    if (process.env.ELECTRON_START_URL) {
        // 开发环境：直接引用 src 下的资源
        iconPath = path.join(__dirname, '../src/assets/logo.png');
    } else {
        // 生产环境：引用复制到 electron/assets 下的资源
        iconPath = path.join(__dirname, 'assets/logo.png');
    }

    tray = new Tray(iconPath);

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
                const config = loadConfig() || {};
                config.autoLaunch = newState;
                saveConfig(config);
            }
        },
        {
            label: '访问官网',
            click: () => {
                shell.openExternal('https://memoryflow.tanxhub.com');
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

    tray.on('click', () => {
        if (widgetWindow.isVisible()) {
            widgetWindow.hide();
        } else {
            widgetWindow.show();
        }
    });
}

function createWidgetWindow() {
    const { width: screenWidth } = screen.getPrimaryDisplay().workAreaSize;
    // 使用固定的最大尺寸，避免动画时的窗口调整导致闪烁
    const initialWidth = 620; 
    const initialHeight = 300;

    // Create the browser window.
    widgetWindow = new BrowserWindow({
        width: initialWidth,
        height: initialHeight, 
        x: Math.floor((screenWidth - initialWidth) / 2), // Center horizontally
        y: 0, // Stick to top edge
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
            const { width: screenWidth } = screen.getPrimaryDisplay().workAreaSize;
            const x = Math.floor((screenWidth - width) / 2);
            // 保持 y = 0，更新宽度和高度，并水平居中
            widgetWindow.setBounds({ x, y: 0, width, height });
        }
    });

    // Load the app
    // In production, we need to load the index.html and handle the hash route manually if needed, 
    // or ensure the app handles the default route correctly.

    if (process.env.ELECTRON_START_URL) {
        widgetWindow.loadURL(process.env.ELECTRON_START_URL + '#/widget');
    } else {
        // For production (file:// protocol), use loadFile which handles paths correctly on Windows
        const indexPath = path.join(__dirname, '../dist/index.html');
        // Load file directly with hash is tricky in Electron loadFile, using loadURL with file protocol is safer for hash
        widgetWindow.loadURL(`file://${indexPath}#/widget`);
    }

    widgetWindow.webContents.on('did-finish-load', () => {
        if (pendingAuthToken) {
            sendTokenToRenderer(pendingAuthToken);
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
