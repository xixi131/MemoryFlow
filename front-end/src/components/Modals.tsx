import React, { useState, useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { message } from './Message';

interface ModalProps {
    onClose: () => void;
    children: React.ReactNode;
    className?: string;
}

export const ModalWrapper: React.FC<ModalProps> = ({ onClose, children, className }) => {
    return (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 sm:p-6">
            <div className="absolute inset-0 bg-slate-900/20 dark:bg-[#0F172A]/50 backdrop-blur-md transition-opacity duration-300" onClick={onClose}></div>
            {(() => {
                // 如果调用方已传入 max-w-*，则不再强制使用默认的 max-w-5xl
                const hasCustomMaxW = !!className && /(^|\\s)max-w-/.test(className);
                const base =
                    'relative w-full rounded-[2rem] shadow-2xl shadow-black/10 dark:shadow-black/50 flex flex-col overflow-hidden transform transition-all modal-enter max-h-[90vh]';
                const width = hasCustomMaxW ? '' : ' max-w-5xl';
                const surface = className || 'bg-white dark:bg-surface-dark border border-slate-200 dark:border-white/10';
                return <div className={`${base}${width} ${surface}`}>{children}</div>;
            })()}
        </div>
    );
};

export const AddSubjectModal: React.FC<{ onClose: () => void; onCreate: (title: string, content: string) => void }> = ({ onClose, onCreate }) => {
    const [title, setTitle] = useState('计算机算法设计');
    const [showTooltip, setShowTooltip] = useState(false);
    const [typedText, setTypedText] = useState('');
    const fullTooltipText = "点击AI辅助生成即可复制格式要求提示词";

    useEffect(() => {
        let timer: any;
        if (showTooltip) {
            setTypedText('');
            let currentIndex = 0;
            timer = setInterval(() => {
                if (currentIndex < fullTooltipText.length) {
                    setTypedText(fullTooltipText.slice(0, currentIndex + 1));
                    currentIndex++;
                } else {
                    clearInterval(timer);
                }
            }, 50);
        } else {
            setTypedText('');
        }
        return () => clearInterval(timer);
    }, [showTooltip]);

    const handleCopyPrompt = () => {
        const prompt = `请作为一个专业的课程设计助手，帮我把以下内容整理成结构化的知识点数据。

格式严格要求如下（自定义DSL）：
1. 一级章节使用 "@ " 开头（例如：@ 数据结构）
2. 二级知识点使用 "@@ " 开头（例如：@@ 二叉树遍历）
3. 详细文章内容使用 JSON 格式包裹，必须包含 title 和 content 字段：
   {title: "文章标题", content: "这里是Markdown格式的正文内容"}

注意事项：
- content 内部必须是合法的 Markdown 字符串，注意转义。
- 一个二级知识点下可以有多个 JSON 文章对象（换行分隔）。
- 请确保结构清晰，层级分明。

示例输出：
@ 算法基础
@@ 排序算法
{title: "快速排序详解", content: "# 快速排序\\n\\n快排的核心思想是分治..."}
{title: "归并排序", content: "# 归并排序\\n\\n归并排序是稳定的排序算法..."}

请根据以上规则，整理以下内容：`;
        
        navigator.clipboard.writeText(prompt).then(() => {
            message.success("提示词已复制到剪贴板");
        }).catch(() => {
            message.error("复制失败");
        });
    };

    const [content, setContent] = useState(`@ 搜索算法基础

@@ DFS (深度优先搜索)

{title: "回溯算法实践", content: "
# 回溯算法实践详解

## 1. 什么是回溯算法
回溯算法是一种**穷举搜索**的算法思想，通过\\"尝试-撤销\\"的方式，系统地搜索问题的所有可能解。

### 核心思想
Code
\`\`\`
选择 → 递归 → 撤销选择（回溯）
\`\`\`

可以想象成在**决策树**上进行深度优先搜索（DFS）：
- 每个节点代表一个决策状态
- 从根节点出发，逐步做出选择
- 走不通就退回上一步，尝试其他选择

------

## 2. 回溯算法框架模板

### 通用模板
C++
\`\`\`cpp
void backtrack(路径, 选择列表) {
    if (满足结束条件) {
        result.push_back(路径);
        return;
    }
    for (选择 : 选择列表) {
        // 做选择
        将选择加入路径;
        // 递归
        backtrack(路径, 新的选择列表);
        // 撤销选择（回溯）
        将选择从路径中移除;
    }
}
\`\`\`
"}
{title: "demo标题", content: "测试内容"}

@@ BFS (广度优先搜索)
{title: "层序遍历应用", content: "测试内容"}

@ 动态规划
@@ 背包问题`);

    return (
        <ModalWrapper onClose={onClose}>
            <div className="px-8 pt-10 pb-4 bg-gradient-to-b from-slate-50/50 to-transparent dark:from-white/5 dark:to-transparent">
                <h2 className="text-3xl font-bold text-slate-900 dark:text-white tracking-tight flex items-center gap-3">
                    <span className="material-symbols-outlined text-primary text-3xl">post_add</span>
                    添加新科目
                </h2>
                <p className="text-slate-500 dark:text-text-secondary mt-2 text-base ml-1">支持批量导入与 AI 生成内容格式化</p>
            </div>
            
            <div className="px-8 pb-8 pt-4 flex flex-col gap-8 h-full overflow-y-auto">
                <div className="space-y-3">
                    <label className="text-sm font-bold text-slate-500 dark:text-slate-300 ml-2 uppercase tracking-wide">科目名称 Subject Name</label>
                    <input 
                        className="w-full bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 rounded-full px-6 py-4 text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all shadow-inner text-lg" 
                        placeholder="输入科目名称 (e.g. 算法导论)" 
                        type="text" 
                        value={title}
                        onChange={(e) => setTitle(e.target.value)}
                    />
                </div>

                <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
                    {/* Editor Area */}
                    <div className="lg:col-span-8 flex flex-col gap-3">
                        <div className="flex items-center justify-between px-2">
                            <label className="text-sm font-bold text-slate-500 dark:text-slate-300 uppercase tracking-wide">内容规划 Planning</label>
                            <div 
                                className="relative flex items-center gap-2 text-primary hover:text-blue-600 dark:hover:text-white transition-colors cursor-pointer group"
                                onMouseEnter={() => setShowTooltip(true)}
                                onMouseLeave={() => setShowTooltip(false)}
                                onClick={handleCopyPrompt}
                            >
                                <span className="material-symbols-outlined group-hover:rotate-12 transition-transform">auto_fix</span>
                                <span className="text-xs font-bold">AI 辅助生成</span>
                                
                                {/* Tooltip */}
                                <div className={`absolute bottom-full left-1/2 -translate-x-1/2 mb-3 w-max max-w-[200px] px-3 py-2 bg-slate-800 text-white text-xs rounded-lg shadow-xl pointer-events-none transition-all duration-300 ${showTooltip ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-2'}`}>
                                    {typedText}
                                    <span className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-2 h-2 bg-slate-800 rotate-45"></span>
                                </div>
                            </div>
                        </div>
                        
                        <div className="relative group flex-1">
                            {/* Changed transition-all to transition-shadow to avoid animating background/borders unexpectedly */}
                            <div className="w-full min-h-[320px] bg-slate-900 dark:bg-background-dark rounded-[1.5rem] border border-slate-200 dark:border-white/10 p-1 font-mono text-sm leading-7 shadow-[inset_0_2px_10px_rgba(0,0,0,0.1)] relative overflow-hidden focus-within:ring-2 focus-within:ring-primary/50 transition-shadow duration-300">
                                <textarea 
                                    className="w-full h-full min-h-[320px] bg-transparent text-slate-300 border-0 resize-none ring-0 focus:ring-0 outline-none focus:outline-none p-6 placeholder:text-slate-400 dark:placeholder:text-slate-400 focus:placeholder:text-slate-700 dark:focus:placeholder:text-slate-700 placeholder:transition-colors duration-300"
                                    spellCheck={false}
                                    value={content}
                                    onChange={(e) => setContent(e.target.value)}
                                    placeholder={`@ 搜索算法基础
@@ DFS (深度优先搜索)
{title: "回溯算法实践", content: "..."}
{title: "demo标题", content: "..."}

@ 动态规划`}
                                />
                                {/* Window controls deco */}
                                <div className="absolute top-4 right-4 flex gap-2 pointer-events-none">
                                    <div className="h-3 w-3 rounded-full bg-red-500/20"></div>
                                    <div className="h-3 w-3 rounded-full bg-yellow-500/20"></div>
                                    <div className="h-3 w-3 rounded-full bg-green-500/20"></div>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Syntax Guide */}
                    <div className="lg:col-span-4 flex flex-col gap-3">
                        <label className="text-sm font-bold text-slate-500 dark:text-slate-300 px-2 uppercase tracking-wide">语法指南 Syntax</label>
                        <div className="bg-slate-50 dark:bg-white/5 rounded-[1.5rem] p-6 h-full border border-slate-200 dark:border-white/5 flex flex-col gap-6">
                            {[
                                { symbol: '@', color: 'text-accent-coral', bg: 'bg-accent-coral/10', border: 'border-accent-coral/20', title: '一级章节 (Chapter)', desc: '定义一个新的大章节，例如 "@数据结构"' },
                                { symbol: '@@', color: 'text-cyan-500 dark:text-cyan-400', bg: 'bg-cyan-500/10 dark:bg-cyan-400/10', border: 'border-cyan-500/20 dark:border-cyan-400/20', title: '二级知识点 (Point)', desc: '章节下的具体知识点，例如 "@@DFS"' },
                                { symbol: '{}', color: 'text-emerald-500 dark:text-emerald-400', bg: 'bg-emerald-500/10 dark:bg-emerald-400/10', border: 'border-emerald-500/20 dark:border-emerald-400/20', title: '文章/详情 (Content)', desc: 'JSON格式配置内容，支持多个文章，如 {title: "...", content: "..."}' }
                            ].map((item, idx) => (
                                <div key={idx} className="flex items-start gap-4 p-2 rounded-xl hover:bg-slate-100 dark:hover:bg-white/5 transition-colors">
                                    <div className={`h-10 w-10 shrink-0 rounded-lg ${item.bg} ${item.border} border flex items-center justify-center ${item.color} font-mono font-bold text-xl`}>
                                        {item.symbol}
                                    </div>
                                    <div className="flex flex-col">
                                        <span className="text-slate-900 dark:text-white font-bold text-sm">{item.title}</span>
                                        <span className="text-xs text-slate-500 dark:text-text-secondary leading-relaxed mt-1">{item.desc}</span>
                                    </div>
                                </div>
                            ))}
                            <div className="mt-auto pt-4 border-t border-slate-200 dark:border-white/5">
                                <p className="text-[10px] text-slate-400 dark:text-slate-500 text-center">Tip: 支持从 Markdown 粘贴自动转换</p>
                            </div>
                        </div>
                    </div>
                </div>

                <div className="flex items-center justify-end gap-4 mt-2 pt-6 border-t border-slate-200 dark:border-white/5">
                    <button onClick={onClose} className="px-8 py-3 rounded-full border border-slate-300 dark:border-slate-600 text-slate-500 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-white/5 hover:text-slate-900 dark:hover:text-white hover:border-slate-400 dark:hover:border-white transition-all font-medium text-sm tracking-wide">
                        取消
                    </button>
                    <button onClick={() => onCreate(title, content)} className="group px-8 py-3 rounded-full bg-primary text-white hover:bg-blue-600 dark:hover:bg-primary-glow shadow-lg dark:shadow-[0_4px_20px_-5px_rgba(55,128,246,0.5)] hover:-translate-y-0.5 transition-all font-bold flex items-center gap-2 text-sm tracking-wide">
                        <span className="material-symbols-outlined text-[20px] group-hover:rotate-12 transition-transform">smart_toy</span>
                        智能解析并保存
                    </button>
                </div>
            </div>
        </ModalWrapper>
    );
};


export const EditContentModal: React.FC<{ onClose: () => void; title: string }> = ({ onClose, title }) => {
    return (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-slate-900/20 dark:bg-background-dark/80 backdrop-blur-sm p-4 animate-fade-in">
             <div className="relative w-full max-w-[800px] bg-white dark:bg-[#1E293B]/90 backdrop-blur-xl border border-slate-200 dark:border-white/10 rounded-[2rem] shadow-2xl flex flex-col overflow-hidden animate-modal">
                {/* Glow effects */}
                <div className="pointer-events-none absolute -top-40 -right-40 h-80 w-80 rounded-full bg-primary/10 dark:bg-primary/20 blur-[100px]"></div>
                
                {/* Header */}
                <div className="relative flex items-center justify-between px-8 pt-8 pb-2">
                    <div className="flex flex-col gap-1">
                        <span className="text-xs font-bold uppercase tracking-widest text-primary">编辑内容</span>
                    </div>
                    <button onClick={onClose} className="group flex h-10 w-10 items-center justify-center rounded-full bg-slate-100 dark:bg-white/5 text-slate-500 dark:text-slate-400 transition-colors hover:bg-slate-200 dark:hover:bg-white/10 hover:text-slate-900 dark:hover:text-white active:scale-95">
                        <span className="material-symbols-outlined text-[20px] font-bold">close</span>
                    </button>
                </div>

                <div className="flex flex-1 flex-col overflow-y-auto px-8 pb-4">
                     {/* Title Input */}
                     <div className="mt-2 mb-6">
                        <input autoFocus className="w-full bg-transparent border-0 border-b border-slate-200 dark:border-white/10 px-0 py-4 text-3xl font-bold text-slate-900 dark:text-white placeholder:text-slate-400 dark:placeholder:text-slate-600 focus:border-primary focus:ring-0 transition-all" placeholder="输入标题..." type="text" defaultValue={title} />
                    </div>

                    {/* Editor Mock */}
                    <div className="flex flex-1 flex-col gap-3 min-h-[300px]">
                        <div className="relative flex flex-col w-full flex-1 rounded-2xl bg-slate-50 dark:bg-[#020617] shadow-inner border border-slate-200 dark:border-white/5 overflow-hidden group focus-within:ring-1 focus-within:ring-primary/50 transition-all">
                            {/* Toolbar */}
                            <div className="flex items-center gap-1 border-b border-slate-200 dark:border-white/5 bg-slate-100 dark:bg-slate-900/50 px-2 py-2">
                                {['format_bold', 'format_italic', 'format_list_bulleted', 'link', 'image'].map(icon => (
                                    <button key={icon} className="flex h-8 w-8 items-center justify-center rounded-lg text-slate-500 dark:text-slate-400 hover:bg-white dark:hover:bg-white/10 hover:text-slate-900 dark:hover:text-white transition-colors">
                                        <span className="material-symbols-outlined text-[20px]">{icon}</span>
                                    </button>
                                ))}
                                <div className="flex-1"></div>
                                <span className="text-xs text-slate-400 dark:text-slate-500 pr-2">Markdown 支持</span>
                            </div>
                            <textarea className="flex-1 w-full resize-none bg-transparent p-5 text-base leading-relaxed text-slate-700 dark:text-slate-200 placeholder:text-slate-400 dark:placeholder:text-slate-600 focus:outline-none focus:ring-0 border-none" 
                                placeholder="在这里添加详细笔记..."
                                defaultValue={`量子纠缠（quantum entanglement），或称量子缠结，是一种量子力学现象，是1935年由爱因斯坦、波多尔斯基和罗森提出的一种波，其量子态必需描述为整个系统的叠加...`}
                            ></textarea>
                        </div>
                    </div>
                </div>

                <div className="mt-auto border-t border-slate-200 dark:border-white/5 bg-white/50 dark:bg-surface-dark/50 px-8 py-5 backdrop-blur-md">
                    <div className="flex w-full items-center justify-end gap-3 flex-1">
                        <button onClick={onClose} className="flex h-12 min-w-[100px] items-center justify-center rounded-full border border-slate-300 dark:border-slate-600/50 bg-transparent px-6 text-sm font-bold text-slate-500 dark:text-slate-300 transition-all hover:bg-slate-100 dark:hover:bg-white/5 hover:border-slate-400 dark:hover:border-slate-500 active:scale-95">
                            取消
                        </button>
                        <button onClick={onClose} className="shadow-glow flex h-12 min-w-[120px] items-center justify-center gap-2 rounded-full bg-primary px-8 text-sm font-bold text-white transition-all hover:bg-blue-600 dark:hover:bg-blue-500 active:scale-95">
                            <span className="material-symbols-outlined text-[18px]">save</span>
                            保存
                        </button>
                    </div>
                </div>
             </div>
        </div>
    );
};

export const DeleteConfirmModal: React.FC<{ onClose: () => void; onConfirm: () => void; title: string }> = ({ onClose, onConfirm, title }) => {
    return (
        <ModalWrapper onClose={onClose} className="glass-panel max-w-lg rounded-3xl shadow-lg">
            <div className="flex flex-col items-center justify-center p-8 sm:p-12 text-center animate-fade-in">
                <div className="size-20 rounded-full bg-red-500/10 flex items-center justify-center mb-6">
                    <span className="material-symbols-outlined text-4xl text-red-500">delete_forever</span>
                </div>
                <h3 className="text-2xl font-bold text-slate-900 dark:text-white mb-2">确认删除</h3>
                <p className="text-slate-500 dark:text-text-secondary mb-8 max-w-md">
                    您确定要删除 <span className="font-bold text-slate-900 dark:text-white">"{title}"</span> 吗？此操作无法撤销。
                </p>
                <div className="flex items-center gap-4 w-full justify-center">
                    <button 
                        onClick={onClose}
                        className="px-8 py-3 rounded-full border border-slate-300 dark:border-slate-600 text-slate-500 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-white/5 hover:text-slate-900 dark:hover:text-white hover:border-slate-400 dark:hover:border-white transition-all font-medium text-sm tracking-wide"
                    >
                        取消
                    </button>
                    <button 
                        onClick={onConfirm}
                        className="px-8 py-3 rounded-full bg-red-500 text-white hover:bg-red-600 shadow-lg shadow-red-500/30 hover:-translate-y-0.5 transition-all font-bold flex items-center gap-2 text-sm tracking-wide"
                    >
                        <span className="material-symbols-outlined text-[20px]">delete</span>
                        确认删除
                    </button>
                </div>
            </div>
        </ModalWrapper>
    );
};

export const AddGoalModal: React.FC<{ onClose: () => void; onCreate: (name: string, tag: 'priority' | 'daily' | 'longterm') => void }> = ({ onClose, onCreate }) => {
    const [name, setName] = useState('');
    const [tag, setTag] = useState<'priority' | 'daily' | 'longterm'>('priority');
    const [open, setOpen] = useState(false);
    const anchorRef = useRef<HTMLButtonElement | null>(null);
    const menuRef = useRef<HTMLDivElement | null>(null);
    const [menuPos, setMenuPos] = useState<{ top: number; left: number; width: number } | null>(null);
    const canSave = name.trim().length > 0;
    const updateMenuPos = () => {
        const rect = anchorRef.current?.getBoundingClientRect();
        if (!rect) return;
        const offset = 8;
        const defaultTop = rect.bottom + offset;
        let top = defaultTop;
        if (menuRef.current) {
            const mh = menuRef.current.offsetHeight || 180;
            const spaceBelow = window.innerHeight - rect.bottom;
            if (spaceBelow < mh + offset) {
                top = Math.max(8, rect.top - mh - offset);
            }
        }
        setMenuPos({ top, left: rect.left, width: rect.width });
    };
    useEffect(() => {
        if (open) {
            updateMenuPos();
            const handler = () => updateMenuPos();
            window.addEventListener('resize', handler);
            window.addEventListener('scroll', handler, true);
            const closeOnOutside = (e: MouseEvent) => {
                if (
                    menuRef.current &&
                    anchorRef.current &&
                    !menuRef.current.contains(e.target as Node) &&
                    !anchorRef.current.contains(e.target as Node)
                ) {
                    setOpen(false);
                }
            };
            document.addEventListener('mousedown', closeOnOutside);
            return () => {
                window.removeEventListener('resize', handler);
                window.removeEventListener('scroll', handler, true);
                document.removeEventListener('mousedown', closeOnOutside);
            };
        }
    }, [open]);
    return (
        <ModalWrapper onClose={onClose} className="glass-panel max-w-lg rounded-3xl shadow-lg">
            <div className="flex flex-col gap-6 p-8">
                <div className="flex items-center justify-between">
                    <h3 className="text-xl font-bold text-slate-900 dark:text-white flex items-center gap-2">
                        <span className="material-symbols-outlined text-primary">target</span>
                        新建目标
                    </h3>
                    <button onClick={onClose} className="h-10 w-10 rounded-full flex items-center justify-center text-slate-500 hover:bg-slate-200 dark:text-text-secondary dark:hover:text-white dark:hover:bg-white/10 transition-colors">
                        <span className="material-symbols-outlined">close</span>
                    </button>
                </div>
                <div className="flex flex-col gap-2">
                    <label className="text-sm font-bold text-slate-500 dark:text-slate-300 uppercase tracking-wider">目标名称</label>
                    <input
                        value={name}
                        onChange={(e) => setName(e.target.value)}
                        className="w-full bg-slate-50 dark:bg-background-dark border border-slate-200 dark:border-white/10 rounded-xl px-4 py-3 text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all"
                        placeholder="例如：拿到某公司 Offer"
                        type="text"
                    />
                </div>
                <div className="flex flex-col gap-2">
                    <label className="text-sm font-bold text-slate-500 dark:text-slate-300 uppercase tracking-wider">标签</label>
                    <div className="relative">
                        {(() => {
                            const currentLabel = tag === 'priority' ? '高级优先' : tag === 'daily' ? '每日打卡' : '长期计划';
                            return (
                                <div className="relative">
                                    <button
                                        type="button"
                                        ref={anchorRef}
                                        onClick={() => {
                                            setOpen((prev) => {
                                                if (!prev) updateMenuPos();
                                                return !prev;
                                            });
                                        }}
                                        className="w-full rounded-full px-5 py-3 bg-slate-100 dark:bg-[#0F172A] border border-slate-200 dark:border-white/10 text-slate-900 dark:text-white shadow-inner focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 focus:ring-offset-2 focus:ring-offset-white dark:focus:ring-offset-surface-dark transition-all pr-12 text-left"
                                    >
                                        {currentLabel}
                                        <span className="material-symbols-outlined absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none">expand_more</span>
                                    </button>
                                    {open && menuPos && createPortal(
                                        <div
                                            ref={menuRef}
                                            className="fixed z-[1000] glass-panel rounded-2xl border border-slate-200 dark:border-white/10 shadow-lg overflow-hidden max-h-48 overflow-auto"
                                            style={{ top: menuPos.top, left: menuPos.left, width: menuPos.width }}
                                        >
                                            <button
                                                type="button"
                                                onClick={() => { setTag('priority'); setOpen(false); }}
                                                className={`group w-full text-left px-4 py-3 rounded-xl transition-all ${
                                                    tag === 'priority'
                                                        ? 'bg-slate-100 dark:bg-white/10 ring-1 ring-primary/20'
                                                        : 'hover:bg-slate-100 dark:hover:bg-white/10 hover:shadow-inner'
                                                }`}
                                            >
                                                <span className="mr-2 px-2 py-0.5 rounded-full bg-primary/10 text-primary border border-primary/20 text-xs">高级优先</span>
                                            </button>
                                            <button
                                                type="button"
                                                onClick={() => { setTag('daily'); setOpen(false); }}
                                                className={`group w-full text-left px-4 py-3 rounded-xl transition-all ${
                                                    tag === 'daily'
                                                        ? 'bg-slate-100 dark:bg-white/10 ring-1 ring-primary/20'
                                                        : 'hover:bg-slate-100 dark:hover:bg-white/10 hover:shadow-inner'
                                                }`}
                                            >
                                                <span className="mr-2 px-2 py-0.5 rounded-full bg-purple-500/10 text-purple-500 border border-purple-500/20 text-xs">每日打卡</span>
                                            </button>
                                            <button
                                                type="button"
                                                onClick={() => { setTag('longterm'); setOpen(false); }}
                                                className={`group w-full text-left px-4 py-3 rounded-xl transition-all ${
                                                    tag === 'longterm'
                                                        ? 'bg-slate-100 dark:bg-white/10 ring-1 ring-primary/20'
                                                        : 'hover:bg-slate-100 dark:hover:bg-white/10 hover:shadow-inner'
                                                }`}
                                            >
                                                <span className="mr-2 px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-500 border border-emerald-500/20 text-xs">长期计划</span>
                                            </button>
                                        </div>,
                                        document.body
                                    )}
                                </div>
                            );
                        })()}
                    </div>
                    <div className="flex items-center gap-2 text-xs">
                        <span className="px-2 py-0.5 rounded-full bg-primary/10 text-primary border border-primary/20">高级优先</span>
                        <span className="px-2 py-0.5 rounded-full bg-purple-500/10 text-purple-500 border border-purple-500/20">每日打卡</span>
                        <span className="px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-500 border border-emerald-500/20">长期计划</span>
                    </div>
                </div>
                <div className="flex items-center justify-end gap-3">
                    <button onClick={onClose} className="px-6 py-3 rounded-full border border-slate-300 dark:border-slate-600 text-slate-500 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-white/5 hover:text-slate-900 dark:hover:text-white transition-all text-sm font-medium">
                        取消
                    </button>
                    <button
                        onClick={() => {
                            if (canSave) onCreate(name.trim(), tag);
                        }}
                        className={`px-6 py-3 rounded-full text-sm font-bold flex items-center gap-2 transition-all ${canSave ? 'bg-primary text-white hover:bg-blue-600' : 'bg-slate-200 text-slate-400 cursor-not-allowed'}`}
                    >
                        <span className="material-symbols-outlined">save</span>
                        保存
                    </button>
                </div>
            </div>
        </ModalWrapper>
    );
};
