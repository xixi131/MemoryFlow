# 修复 Windows 下 Widget 加载失败与透明显示问题

## 问题根源
用户反馈“点击托盘显示浮窗，桌面无显示”。结合之前“运行出来是黑色长方形”和修复透明度后的情况，推测原因如下：
1.  **路径格式错误**：在 Windows 上，`path.join` 生成反斜杠 `\`。当直接拼接到 `file://` 后（例如 `file://E:\...\index.html`），这在某些 Electron/Chromium 版本中被视为无效 URL，导致页面加载失败（白屏）。
2.  **透明度副作用**：由于之前设置了 `transparent: true` 且移除了 `body` 背景色，如果页面加载失败（白屏），用户将看到一个完全透明的窗口，即“什么都看不到”。

## 实施方案
1.  **标准化 URL 构建**：
    *   在 `main.cjs` 中引入 `url` 模块。
    *   在生产环境（else 分支）中，不再使用简单的字符串拼接。
    *   使用 `loadFile` 方法加载本地文件，并利用 `hash` 选项指定路由。这是 Electron 官方推荐的方式，能自动处理路径分隔符和协议问题。

    ```javascript
    // 替换原有的 loadURL 逻辑
    const indexPath = path.join(__dirname, '../dist/index.html');
    widgetWindow.loadFile(indexPath, { hash: 'widget' });
    ```

2.  **验证逻辑**：
    *   保留 `process.env.ELECTRON_START_URL` 的逻辑用于开发环境。
    *   确保 `loadFile` 的路径指向正确的 `dist/index.html`。

## 预期效果
*   无论在 Windows 还是其他平台，都能正确加载本地 HTML 文件。
*   Widget 页面成功渲染后，内容将显示在透明窗口上。
