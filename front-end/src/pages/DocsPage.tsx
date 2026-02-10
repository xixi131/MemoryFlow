import React, { useState } from 'react';
import ReactMarkdown from 'react-markdown';
import { useNavigate } from 'react-router-dom';

interface DocSection {
    id: string;
    title: string;
    content: string;
}

const docsData: DocSection[] = [
    {
        id: 'intro',
        title: '1. 产品简介',
        content: `
## 1. 简介 (Introduction)

MemoryFlow 结合了**间隔重复系统 (SRS)** 与**桌面灵动岛 (Dynamic Island)** 交互设计，解决传统学习遗忘知识，无法系统学习的痛点。

在学习的道路上，最让人沮丧的不是“学不会”，而是**“明明学过，却不记得了”**。我们都有过这样的时刻：想复习，却面对厚厚的笔记无从下手；不知道哪些知识点正在遗忘边缘，也不知道哪些其实已经掌握。最终，复习变成了盲目的重复，效率极低。

**MemoryFlow (记忆流)** 正是为此而生。它不是简单的笔记工具，而是你的**智能记忆管家**。它接管了“该复习什么”的决策过程——利用艾宾浩斯遗忘曲线算法，精确计算每一个知识点的最佳复习时间。

你只管学，剩下的交给我们。MemoryFlow 会在最恰当的时刻，通过桌面灵动岛轻声提醒。**告别无序的焦虑，构建系统化的知识堡垒，让每一次复习都精准有效。**

### 设计理念 (Design Philosophy)
*   **Zero-Friction Review (无感复习)**：将复习任务碎片化嵌入桌面常驻组件，降低认知启动门槛。
*   **Unified Experience (统一体验)**：在同一界面无缝切换“专注学习”与“休闲娱乐”状态。
*   **Data-Driven (数据驱动)**：基于艾宾浩斯遗忘曲线算法，动态计算最佳复习时间点。
`
    },
    {
        id: 'features',
        title: '2. 核心功能',
        content: `
## 2. 功能概览 (Features)

### 2.1 桌面灵动岛 (Desktop Dynamic Island)

常驻桌面的核心交互组件，采用极简主义设计，支持双模式自动切换。

*   **应用模式 (App Mode)**：
    
    * **实时概览**：展示今日待复习项 (Pending Reviews) 与今日已完成项 (Completed Today)。
    
    * **交互逻辑**：支持鼠标手势点击自动展开 (Hover Expansion)  切换紧凑/完整视图。
    
      ![灵动岛应用模式](/灵动岛应用模式图片.png)
    
      ![灵动岛应用模式动画](/灵动岛应用模式动画.gif)
    
*   **音乐模式 (Music Mode)**：
    
    * **自动激活**：检测到系统媒体播放时自动接管显示。
    
    * **元数据同步**：实时获取专辑封面、曲名、艺术家信息。
    
    * **动态波纹**：内置音频可视化组件 (Waveform)，随音乐律动。
    
    * **双向控制**：支持通过 Widget 直接控制系统媒体（播放/暂停/切歌）。
    
      ![音乐模式](/灵动岛音乐模式图片.png)
    
      ![灵动岛音乐模式动画](/灵动岛音乐模式动画.gif)

### 2.2 沉浸式音乐控制 (Immersive Music Control)

基于 Windows 系统底层协议实现的媒体接管方案。

*   **技术原理**：集成 \`Windows System Media Transport Controls (SMTC)\` 协议，通过 Electron Worker 线程实现非阻塞式监听。
*   **平台兼容**：原生支持 Spotify、Apple Music、QQ音乐等主流遵循 SMTC 标准的播放器。
*   **视觉增强**：自动提取专辑封面主色调 (Dominant Color Extraction)，实时渲染动态阴影与背景模糊效果。

#### 兼容性说明 (Compatibility Note) - 网易云音乐用户必读
由于网易云音乐 (NetEase Cloud Music) 官方客户端尚未原生支持 SMTC 协议，MemoryFlow 默认无法获取其**实时进度条同步**与**高分辨率封面**。
*   **解决方案**：为获得完美体验，建议安装社区插件 \`BetterNCM\` 并启用 SMTC 桥接模块。
*   **操作指南**：请参考技术博客 [让网易云支持 SMTC - 一叶舟记](https://blog.lonzov.top/posts/betterncm/) 完成配置。配置完成后，MemoryFlow 即可实现毫秒级进度同步与无损封面显示。

![灵动岛音乐模式音乐控制动画](/灵动岛音乐模式音乐控制动画.gif)

### 2.3 AI 驱动的知识架构 (AI-Powered Knowledge Architecture)

利用 LLM (大型语言模型) 的推理能力，将非结构化知识一键转化为系统化的学习路径。

*   **一键指令生成 (One-Click Prompting)**：
    *   用户只需点击 **"AI 辅助生成"**，系统自动将复杂的结构化数据规范（JSON Schema）封装为优化的提示词 (Prompt) 并复制到剪贴板。
*   **结构化解析引擎 (Structured Parsing Engine)**：
    *   直接将 AI 生成的回复粘贴回系统，MemoryFlow 会自动进行语法树解析。
    *   **自动分点规划**：自动将庞大的知识体系拆解为 \`Chapter\` (章节) 和 \`Key Point\` (知识点)，并自动规划学习进度条。
*   **系统化学习 (Systematic Learning)**：
    *   不仅是生成内容，更是生成**学习路径**。从宏观的科目大纲到微观的记忆卡片，AI 辅助构建完整的知识图谱，确保学习过程循序渐进，无遗漏。

![AI 驱动的知识架构动画](/AI 驱动的知识架构动画.gif)

### 2.4 英语单词掌握引擎 (Language Mastery Engine)

专为语言学习者打造的深度记忆模块，融合权威词库与智能算法。

*   **标准化词库集成 (Standardized Lexicon Integration)**：
    *   内置 **CET-4/6 (四六级)**、**Postgraduate (考研)**、**TOEFL (托福)**、**IELTS (雅思)** 等权威标准化词库。
    *   数据源经多重清洗，包含精准的释义、IPA 音标、原声发音及经典例句。
*   **时空记忆回溯 (Temporal Memory Trace)**：
    *   **时间轴查询**：支持通过日历视图（Calendar View）回溯任意日期的学习轨迹，精准定位“那一天背过的单词”。
    *   **情境重现**：不仅仅是单词列表，系统能还原当时学习的上下文状态，帮助构建情境记忆。
*   **算法级无感推送 (Algorithmic Frictionless Push)**：
    *   **动态调度**：基于改进版艾宾浩斯遗忘曲线 (Ebbinghaus Forgetting Curve)，算法精确计算每个单词的“记忆半衰期”。
    *   **无感介入**：无需用户手动安排复习计划。当单词即将滑入遗忘区时，系统会自动将其无缝注入到今日的复习队列中，实现“在遗忘发生前一秒将其挽回”。

![英语模块背单词动画](/英语模块背单词动画.gif)

![英语模块日历回溯动画](/英语模块日历回溯动画.gif)

### 2.5 极致 UI 工程 (UI Engineering)

*   **Squircle 渲染**：弃用标准圆角，采用数学优化的超椭圆 (Super-ellipse) 路径，实现 iOS 级平滑边角。
*   **流体动画**：基于 Framer Motion 实现布局形变 (Layout Morphing)，确保组件尺寸变化时的物理真实感。
`
    },
    {
        id: 'install',
        title: '3. 获取与安装',
        content: `
## 3. 获取与安装 (Access & Installation)

鉴于服务器资源限制与测试阶段的稳定性考量，MemoryFlow 目前采用**邀请制 (Invite-only)** 分发。

### 3.1 先决条件 (Prerequisites)
*   **操作系统**：Windows 10 (Build 19041+) 或 Windows 11。
*   **运行环境**：无需预装 Node.js 或 Java，安装包已内置所有依赖。

### 3.2 注册流程 (Registration)
1.  联系管理员获取**专属邀请链接 (Invitation Link)**。
2.  访问注册页面，完成账户创建并通过 Cloudflare 安全验证。
3.  *注意：未授权的注册请求将被系统自动拦截。*

### 3.3 客户端下载 (Client Download)
1.  登录 [MemoryFlow 管理后台](http://localhost:3000)。
2.  导航至 **Settings (设置)** > **Client (客户端)**。
3.  点击 **Download for Windows** 获取最新版 \`.exe\` 安装程序。
`
    },
    {
        id: 'faq',
        title: '4. 常见问题',
        content: `
## 4. 常见问题 (FAQ)

**Q: 为什么我无法注册？**
A: 目前仅开放邀请注册，请联系管理员获取邀请码。

**Q: 是否支持 Mac 或 Linux？**
A: 目前仅支持 Windows 平台，Mac 和 Linux 版本正在计划中。

**Q: 数据是否会同步？**
A: 是的，所有学习数据都会实时同步到云端。
`
    }
];

export const DocsPage: React.FC = () => {
    const [currentDocId, setCurrentDocId] = useState<string>(docsData[0].id);
    const navigate = useNavigate();

    // Find current doc index
    const currentIndex = docsData.findIndex(doc => doc.id === currentDocId);
    const currentDoc = docsData[currentIndex];

    // Previous and Next docs
    const prevDoc = currentIndex > 0 ? docsData[currentIndex - 1] : null;
    const nextDoc = currentIndex < docsData.length - 1 ? docsData[currentIndex + 1] : null;

    const handleDocChange = (id: string) => {
        setCurrentDocId(id);
        window.scrollTo({ top: 0, behavior: 'smooth' });
    };

    return (
        <div className="flex min-h-screen bg-white dark:bg-slate-900 pt-16">
            {/* Header */}
            <header className="fixed top-0 left-0 right-0 h-16 bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-700 z-50 flex items-center px-4 md:px-8 justify-between">
                <div className="flex items-center gap-4">
                    <button onClick={() => navigate('/')} className="flex items-center gap-2 text-slate-900 dark:text-white hover:opacity-80 transition-opacity">
                         <img 
                            src="/logo-memoryflow.png" 
                            alt="MemoryFlow Logo" 
                            className="h-8 w-auto object-contain"
                         />
                         <span className="text-xl font-bold tracking-tight">MemoryFlow Docs</span>
                    </button>
                </div>
                <div className="flex items-center gap-4">
                     <button onClick={() => navigate('/')} className="text-sm font-medium text-slate-600 dark:text-slate-400 hover:text-blue-600 dark:hover:text-blue-400 transition-colors">
                        Back to Home
                     </button>
                </div>
            </header>

            {/* Sidebar */}
            <aside className="w-64 fixed top-16 bottom-0 overflow-y-auto border-r border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/50 hidden md:block">
                <nav className="p-4 space-y-1">
                    {docsData.map((doc) => (
                        <button
                            key={doc.id}
                            onClick={() => handleDocChange(doc.id)}
                            className={`w-full text-left px-4 py-3 rounded-lg text-sm font-medium transition-colors border-l-4 ${
                                currentDocId === doc.id
                                    ? 'bg-blue-50 text-blue-600 border-blue-600 dark:bg-blue-900/20 dark:text-blue-400'
                                    : 'text-slate-600 hover:bg-slate-100 border-transparent dark:text-slate-400 dark:hover:bg-slate-800'
                            }`}
                        >
                            {doc.title}
                        </button>
                    ))}
                </nav>
            </aside>

            {/* Main Content */}
            <main className="flex-1 md:ml-64 px-4 md:px-12 py-8 max-w-5xl mx-auto w-full">
                <article className="prose prose-slate prose-lg dark:prose-invert max-w-none">
                     <ReactMarkdown
                        components={{
                            img: ({node, ...props}) => (
                                <span className="block my-4">
                                    <img 
                                        {...props} 
                                        className="rounded-lg shadow-lg max-w-full border border-slate-200 dark:border-slate-700" 
                                        alt={props.alt || ''}
                                    />
                                </span>
                            ),
                            h1: ({node, ...props}) => <h1 className="text-3xl font-bold text-slate-900 dark:text-white mb-6 pb-2 border-b border-slate-200 dark:border-slate-700" {...props} />,
                            h2: ({node, ...props}) => <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100 mt-10 mb-4" {...props} />,
                            h3: ({node, ...props}) => <h3 className="text-xl font-semibold text-slate-700 dark:text-slate-200 mt-8 mb-3" {...props} />,
                            p: ({node, ...props}) => <p className="text-slate-600 dark:text-slate-300 leading-7 mb-4" {...props} />,
                            ul: ({node, ...props}) => <ul className="list-disc list-outside ml-6 text-slate-600 dark:text-slate-300 mb-4" {...props} />,
                            li: ({node, ...props}) => <li className="mb-2 pl-1" {...props} />,
                            strong: ({node, ...props}) => <strong className="font-bold text-slate-900 dark:text-white" {...props} />,
                            blockquote: ({node, ...props}) => <blockquote className="border-l-4 border-blue-500 pl-4 italic bg-blue-50 dark:bg-blue-900/20 py-2 pr-4 rounded my-4 text-slate-700 dark:text-slate-300" {...props} />,
                            a: ({node, ...props}) => (
                                <a 
                                    className="inline-flex items-center gap-1 text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 font-medium hover:underline transition-colors" 
                                    target="_blank" 
                                    rel="noopener noreferrer" 
                                    {...props}
                                >
                                    {props.children}
                                    <span className="material-symbols-outlined text-[16px]">open_in_new</span>
                                </a>
                            ),
                            code: ({node, className, children, ...props}) => {
                                const match = /language-(\w+)/.exec(className || '')
                                return !className ? (
                                    <code className="bg-slate-100 dark:bg-slate-800 px-1.5 py-0.5 rounded text-sm font-mono text-pink-600 dark:text-pink-400" {...props}>
                                        {children}
                                    </code>
                                ) : (
                                    <pre className="bg-slate-900 text-slate-50 p-4 rounded-lg overflow-x-auto mb-4">
                                        <code className={className} {...props}>
                                            {children}
                                        </code>
                                    </pre>
                                )
                            }
                        }}
                     >
                        {currentDoc.content}
                     </ReactMarkdown>
                </article>

                {/* Footer Navigation */}
                <div className="mt-16 pt-8 border-t border-slate-200 dark:border-slate-700 flex flex-col sm:flex-row justify-between gap-4">
                    {prevDoc ? (
                        <button
                            onClick={() => handleDocChange(prevDoc.id)}
                            className="group flex flex-col p-4 rounded-xl border border-slate-200 dark:border-slate-700 hover:border-blue-400 dark:hover:border-blue-500 hover:shadow-md transition-all text-left w-full sm:w-1/2 bg-white dark:bg-slate-800"
                        >
                            <span className="text-sm text-slate-500 dark:text-slate-400 mb-1 group-hover:text-blue-600 dark:group-hover:text-blue-400">← Previous</span>
                            <span className="text-lg font-semibold text-slate-800 dark:text-white group-hover:text-blue-700 dark:group-hover:text-blue-300">{prevDoc.title}</span>
                        </button>
                    ) : (
                        <div className="hidden sm:block w-1/2" />
                    )}

                    {nextDoc ? (
                        <button
                            onClick={() => handleDocChange(nextDoc.id)}
                            className="group flex flex-col items-end p-4 rounded-xl border border-slate-200 dark:border-slate-700 hover:border-blue-400 dark:hover:border-blue-500 hover:shadow-md transition-all text-right w-full sm:w-1/2 bg-white dark:bg-slate-800"
                        >
                            <span className="text-sm text-slate-500 dark:text-slate-400 mb-1 group-hover:text-blue-600 dark:group-hover:text-blue-400">Next →</span>
                            <span className="text-lg font-semibold text-slate-800 dark:text-white group-hover:text-blue-700 dark:group-hover:text-blue-300">{nextDoc.title}</span>
                        </button>
                    ) : (
                        <div className="hidden sm:block w-1/2" />
                    )}
                </div>
            </main>
        </div>
    );
};

export default DocsPage;
