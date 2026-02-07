# 修复 MemoryFlow Widget 显示与托盘问题

## 问题分析
1.  **系统托盘缺失**：打包后 `src/assets` 目录未被正确包含在 Electron 主进程的可访问路径中，导致 `main.cjs` 无法加载托盘图标。
2.  **Widget 显示为黑色长方形**：`index.html` 的 `<body>` 标签设置了全局背景色（`bg-slate-50 dark:bg-background-dark`），导致即使 Electron 窗口设置了 `transparent: true`，内容区域仍有背景色。

## 实施方案
1.  **修复系统托盘图标**
    *   在 `front-end/electron` 下创建 `assets` 目录。
    *   将 `src/assets/logo.png` 复制到 `electron/assets/logo.png`。
    *   修改 `main.cjs` 中的图标引用路径，使其在打包后指向正确位置。

2.  **修复透明度显示**
    *   修改 `index.html`：移除 `<body>` 标签上的背景颜色类。
    *   修改 `App.tsx`：
        *   为应用的主体内容添加一个包装层（`<div>`），将原本在 body 上的背景样式应用到该层。
        *   对 `view === 'widget'` 的情况，保持背景透明（`bg-transparent`）。

## 后续操作
*   请重新运行 `npm run build` 进行打包，安装后即可验证修复效果。
