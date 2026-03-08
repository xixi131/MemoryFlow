import React, { useMemo, useState } from 'react';
import { message } from './Message';
import TyporaEditor from './TyporaEditor';

type InputMode = 'visual' | 'dsl';

interface VisualArticle {
    id: string;
    title: string;
    content: string;
}

interface VisualPoint {
    id: string;
    title: string;
    articles: VisualArticle[];
}

interface VisualChapter {
    id: string;
    title: string;
    articles: VisualArticle[];
    points: VisualPoint[];
}

interface AddSubjectModalProps {
    onClose: () => void;
    onCreate: (
        title: string,
        content: string,
        options?: { targetChapterId?: string; targetPointId?: string }
    ) => void;
    mode?: 'create' | 'append';
    subjectTitle?: string;
    initialChapterId?: string;
    initialChapterTitle?: string;
    initialPointId?: string;
    initialPointTitle?: string;
    restrictToSingleChapter?: boolean;
    restrictToSinglePoint?: boolean;
}

const uid = () => `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;

const createArticle = (): VisualArticle => ({ id: uid(), title: '', content: '' });
const createPoint = (): VisualPoint => ({ id: uid(), title: '', articles: [createArticle()] });
const createChapter = (): VisualChapter => ({ id: uid(), title: '', articles: [createArticle()], points: [] });

const defaultDslContent = `@ 搜索算法基础
@@ DFS (深度优先搜索)
{title: "回溯算法实践", content: "# 回溯算法实践详解\\n\\n请在这里编写内容..."}

@@ BFS (广度优先搜索)
{title: "层序遍历应用", content: "测试内容"}

@ 动态规划
@@ 背包问题`;

const buildDslFromVisual = (chapters: VisualChapter[]) => {
    const lines: string[] = [];

    chapters.forEach((chapter) => {
        const chapterTitle = chapter.title.trim();
        if (!chapterTitle) return;
        lines.push(`@ ${chapterTitle}`);
        lines.push('');

        const chapterLevelArticles = chapter.articles
            .map((article) => ({ title: article.title.trim(), content: article.content.trim() }))
            .filter((a) => a.title || a.content);

        if (chapterLevelArticles.length > 0) {
            chapterLevelArticles.forEach((article) => {
                const safeTitle = JSON.stringify(article.title || '未命名内容');
                const safeContent = JSON.stringify(article.content || '');
                lines.push(`{title: ${safeTitle}, content: ${safeContent}}`);
            });
            lines.push('');
        }

        chapter.points.forEach((point) => {
            const pointTitle = point.title.trim();
            if (!pointTitle) return;
            lines.push(`@@ ${pointTitle}`);
            lines.push('');

            point.articles.forEach((article) => {
                const at = article.title.trim();
                const ac = article.content.trim();
                if (!at && !ac) return;
                const safeTitle = JSON.stringify(at || '未命名内容');
                const safeContent = JSON.stringify(ac || '');
                lines.push(`{title: ${safeTitle}, content: ${safeContent}}`);
            });

            lines.push('');
        });
    });

    return lines.join('\n').trim();
};

const AddSubjectModal: React.FC<AddSubjectModalProps> = ({
    onClose,
    onCreate,
    mode = 'create',
    subjectTitle,
    initialChapterId,
    initialChapterTitle,
    initialPointId,
    initialPointTitle,
    restrictToSingleChapter = false,
    restrictToSinglePoint = false
}) => {
    const isAppendMode = mode === 'append';
    const [inputMode, setInputMode] = useState<InputMode>('visual');
    const [title, setTitle] = useState(isAppendMode ? (subjectTitle || '') : '');
    const [dslContent, setDslContent] = useState(defaultDslContent);
    const [chapters, setChapters] = useState<VisualChapter[]>(() => {
        if (initialChapterTitle?.trim()) {
            if (restrictToSinglePoint && initialPointTitle?.trim()) {
                return [
                    {
                        ...createChapter(),
                        title: initialChapterTitle.trim(),
                        articles: [],
                        points: [{ ...createPoint(), title: initialPointTitle.trim() }]
                    }
                ];
            }
            return [{ ...createChapter(), title: initialChapterTitle.trim() }];
        }
        return [createChapter()];
    });
    const [activeChapterArticleByChapter, setActiveChapterArticleByChapter] = useState<Record<string, string>>({});
    const [activeArticleByPoint, setActiveArticleByPoint] = useState<Record<string, string>>({});
    const [chapterTitleErrors, setChapterTitleErrors] = useState<Record<string, boolean>>({});

    const modalTitle = isAppendMode ? '科目添加内容' : '添加新科目';
    const helperText = isAppendMode
        ? restrictToSinglePoint
            ? `当前将直接为知识点「${initialPointTitle || ''}」补充多个详细内容`
            : restrictToSingleChapter
            ? `当前将直接为章节「${initialChapterTitle || ''}」补充内容`
            : '保留 DSL 批量导入，同时支持可视化手动构建层级'
        : '选择可视化手动添加，或使用 DSL / AI 一次性批量导入';

    const visualDslPreview = useMemo(() => buildDslFromVisual(chapters), [chapters]);

    const copyPrompt = async () => {
        const prompt = `请作为课程设计助手，按以下 DSL 输出：
1) 一级章节：@ 章节标题
2) 二级知识点：@@ 知识点标题
3) 文章内容：{title: "标题", content: "Markdown正文"}
要求：文章内容既可以直接挂在一级章节下，也可以挂在二级知识点下；且同级可有多个文章对象。`;

        try {
            await navigator.clipboard.writeText(prompt);
            message.success('提示词已复制到剪贴板');
        } catch {
            message.error('复制失败');
        }
    };

    const updateChapter = (chapterId: string, updater: (chapter: VisualChapter) => VisualChapter) => {
        setChapters((prev) => prev.map((c) => (c.id === chapterId ? updater(c) : c)));
    };

    const addChapter = () => {
        if (restrictToSingleChapter || restrictToSinglePoint) return;
        setChapters((prev) => [...prev, createChapter()]);
    };
    const removeChapter = (chapterId: string) => {
        if (restrictToSingleChapter || restrictToSinglePoint) return;
        setChapters((prev) => (prev.length <= 1 ? prev : prev.filter((c) => c.id !== chapterId)));
        setActiveChapterArticleByChapter((prev) => {
            const next = { ...prev };
            delete next[chapterId];
            return next;
        });
        setChapterTitleErrors((prev) => {
            const next = { ...prev };
            delete next[chapterId];
            return next;
        });
    };

    const addChapterArticle = (chapterId: string) => {
        const targetChapter = chapters.find((chapter) => chapter.id === chapterId);
        if (!targetChapter?.title.trim()) {
            setChapterTitleErrors((prev) => ({ ...prev, [chapterId]: true }));
            message.warning('请先填写章节标题，再添加章节内容');
            return;
        }

        const nextArticle = createArticle();
        updateChapter(chapterId, (chapter) => ({ ...chapter, articles: [...chapter.articles, nextArticle] }));
        setActiveChapterArticleByChapter((prev) => ({ ...prev, [chapterId]: nextArticle.id }));
    };

    const removeChapterArticle = (chapterId: string, articleId: string) => {
        let nextActiveId: string | undefined;
        updateChapter(chapterId, (chapter) => {
            const filtered = chapter.articles.filter((a) => a.id !== articleId);
            nextActiveId = filtered[0]?.id;
            return { ...chapter, articles: filtered };
        });
        setActiveChapterArticleByChapter((prev) => {
            const next = { ...prev };
            if (nextActiveId) next[chapterId] = nextActiveId;
            else delete next[chapterId];
            return next;
        });
    };

    const addPoint = (chapterId: string) => {
        if (restrictToSinglePoint) return;
        const targetChapter = chapters.find((chapter) => chapter.id === chapterId);
        if (!targetChapter?.title.trim()) {
            setChapterTitleErrors((prev) => ({ ...prev, [chapterId]: true }));
            message.warning('请先填写章节标题，再添加知识点');
            return;
        }

        updateChapter(chapterId, (chapter) => ({ ...chapter, points: [...chapter.points, createPoint()] }));
    };

    const removePoint = (chapterId: string, pointId: string) => {
        if (restrictToSinglePoint) return;
        updateChapter(chapterId, (chapter) => ({
            ...chapter,
            points: chapter.points.filter((p) => p.id !== pointId)
        }));
        setActiveArticleByPoint((prev) => {
            const next = { ...prev };
            delete next[pointId];
            return next;
        });
    };

    const addArticle = (chapterId: string, pointId: string) => {
        const nextArticle = createArticle();
        updateChapter(chapterId, (chapter) => ({
            ...chapter,
            points: chapter.points.map((p) =>
                p.id === pointId ? { ...p, articles: [...p.articles, nextArticle] } : p
            )
        }));
        setActiveArticleByPoint((prev) => ({ ...prev, [pointId]: nextArticle.id }));
    };

    const removeArticle = (chapterId: string, pointId: string, articleId: string) => {
        let nextActiveId: string | undefined;
        updateChapter(chapterId, (chapter) => ({
            ...chapter,
            points: chapter.points.map((p) => {
                if (p.id !== pointId) return p;
                const filtered = p.articles.filter((a) => a.id !== articleId);
                nextActiveId = filtered[0]?.id;
                return {
                    ...p,
                    articles: filtered
                };
            })
        }));
        if (nextActiveId) {
            setActiveArticleByPoint((prev) => ({ ...prev, [pointId]: nextActiveId! }));
        } else {
            setActiveArticleByPoint((prev) => {
                const next = { ...prev };
                delete next[pointId];
                return next;
            });
        }
    };

    const handleSubmit = () => {
        setChapterTitleErrors({});

        const actualTitle = isAppendMode ? (subjectTitle || title).trim() : title.trim();
        if (!isAppendMode && !actualTitle) {
            message.warning('请输入科目名称');
            return;
        }

        let actualContent = '';
        if (inputMode === 'dsl') {
            actualContent = dslContent.trim();
            if (!actualContent) {
                message.warning('请输入要添加的内容');
                return;
            }
            const hasChapter = /(^|\n)\s*@\s+\S+/.test(actualContent);
            if (!hasChapter) {
                message.warning('请至少填写一个章节标题（使用 @ 章节名）');
                return;
            }
        } else {
            const chapterHasContent = (chapter: VisualChapter) => {
                const hasChapterArticles = chapter.articles.some(
                    (article) => article.title.trim() || article.content.trim()
                );
                const hasPoints = chapter.points.some((point) =>
                    point.title.trim() ||
                    point.articles.some((article) => article.title.trim() || article.content.trim())
                );
                return hasChapterArticles || hasPoints;
            };

            const invalidChapterIds = chapters
                .filter((chapter) => !chapter.title.trim() && chapterHasContent(chapter))
                .map((chapter) => chapter.id);

            if (invalidChapterIds.length > 0) {
                setChapterTitleErrors(
                    invalidChapterIds.reduce<Record<string, boolean>>((acc, id) => {
                        acc[id] = true;
                        return acc;
                    }, {})
                );
                message.warning('有章节未填写标题，请先补全章节标题');
                return;
            }

            actualContent = visualDslPreview.trim();
            const hasAnyContent = chapters.some((chapter) => chapterHasContent(chapter));

            if (!hasAnyContent || !actualContent) {
                message.warning('请至少添加一条内容（可在章节直连内容或知识点下添加）');
                return;
            }
        }

        onCreate(
            actualTitle,
            actualContent,
            restrictToSinglePoint && initialChapterId && initialPointId
                ? { targetChapterId: initialChapterId, targetPointId: initialPointId }
                : restrictToSingleChapter && initialChapterId
                ? { targetChapterId: initialChapterId }
                : undefined
        );
    };

    return (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 sm:p-6">
            <div className="absolute inset-0 bg-slate-900/20 dark:bg-[#0F172A]/50 backdrop-blur-md" onClick={onClose}></div>
            <div className="relative w-full max-w-6xl rounded-[2rem] shadow-2xl shadow-black/10 dark:shadow-black/50 flex flex-col overflow-hidden max-h-[92vh] bg-white dark:bg-surface-dark border border-slate-200/70 dark:border-white/10 modal-enter">
                <div className="px-8 pt-8 pb-4 bg-gradient-to-b from-slate-50/50 to-transparent dark:from-white/5 dark:to-transparent">
                    <div className="flex items-start justify-between gap-4">
                        <div>
                            <h2 className="text-3xl font-bold text-slate-900 dark:text-white tracking-tight flex items-center gap-3">
                                <span className="material-symbols-outlined text-primary text-3xl">post_add</span>
                                {modalTitle}
                            </h2>
                            <p className="text-slate-500 dark:text-text-secondary mt-2 text-base ml-1">{helperText}</p>
                        </div>
                        <button
                            onClick={onClose}
                            className="h-10 w-10 rounded-full flex items-center justify-center text-slate-500 hover:bg-slate-200 dark:text-text-secondary dark:hover:text-white dark:hover:bg-white/10 transition-colors"
                        >
                            <span className="material-symbols-outlined">close</span>
                        </button>
                    </div>
                </div>

                <div className="px-8 pb-8 pt-2 flex flex-col gap-7 overflow-y-auto">
                    <div className="space-y-2.5">
                        <label className="text-sm font-bold text-slate-500 dark:text-slate-300 ml-2 uppercase tracking-wide">
                            科目名称
                        </label>
                        <input
                            readOnly={isAppendMode}
                            value={isAppendMode ? (subjectTitle || '') : title}
                            onChange={(e) => setTitle(e.target.value)}
                            placeholder="输入科目名称 (e.g. 计算机网络)"
                            className={`w-full border-0 ring-0 outline-none shadow-none bg-slate-100 dark:bg-[#0f172a]/80 rounded-full px-6 py-4 text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500 focus:border-0 focus:outline-none focus:ring-2 focus:ring-primary/35 transition-all text-lg ${isAppendMode ? 'opacity-80 cursor-not-allowed' : ''}`}
                        />
                    </div>

                    <div className="flex flex-wrap items-center gap-3 pb-1">
                        <span className="text-xs font-bold uppercase tracking-widest text-slate-400">添加方式</span>
                        {!(restrictToSingleChapter || restrictToSinglePoint) ? (
                            <>
                                <div className="inline-flex rounded-full p-1 bg-slate-100 dark:bg-[#0F172A] border border-slate-200 dark:border-white/10">
                                    <button
                                        onClick={() => setInputMode('visual')}
                                        className={`px-4 py-2 rounded-full text-sm font-bold transition-all ${inputMode === 'visual' ? 'bg-primary text-white shadow-glow' : 'text-slate-500 dark:text-text-secondary hover:text-slate-900 dark:hover:text-white'}`}
                                    >
                                        可视化手动
                                    </button>
                                    <button
                                        onClick={() => setInputMode('dsl')}
                                        className={`px-4 py-2 rounded-full text-sm font-bold transition-all ${inputMode === 'dsl' ? 'bg-primary text-white shadow-glow' : 'text-slate-500 dark:text-text-secondary hover:text-slate-900 dark:hover:text-white'}`}
                                    >
                                        DSL / AI 批量
                                    </button>
                                </div>
                                {inputMode === 'dsl' && (
                                    <button
                                        onClick={copyPrompt}
                                        className="ml-auto flex items-center gap-2 px-4 py-2 rounded-full bg-primary/10 text-primary hover:bg-primary/20 transition-colors text-sm font-bold"
                                    >
                                        <span className="material-symbols-outlined text-[18px]">auto_fix</span>
                                        复制 AI 提示词
                                    </button>
                                )}
                            </>
                        ) : (
                            <span className="px-3 py-1.5 rounded-full bg-primary/10 text-primary text-xs font-bold">
                                {restrictToSinglePoint ? '已锁定为当前知识点的可视化添加' : '已锁定为当前章节的可视化添加'}
                            </span>
                        )}
                    </div>

                    {inputMode === 'dsl' && (
                        <div className="grid grid-cols-1 lg:grid-cols-12 gap-5">
                            <div className="lg:col-span-8">
                                <div className="w-full min-h-[360px] bg-slate-900 dark:bg-background-dark rounded-[1.5rem] p-1 font-mono text-sm leading-7 shadow-[inset_0_2px_10px_rgba(0,0,0,0.1)]">
                                    <textarea
                                        className="w-full h-full min-h-[360px] bg-transparent text-slate-300 border-0 resize-none ring-0 focus:ring-0 outline-none p-6"
                                        spellCheck={false}
                                        value={dslContent}
                                        onChange={(e) => setDslContent(e.target.value)}
                                    />
                                </div>
                            </div>
                            <div className="lg:col-span-4 bg-slate-50/85 dark:bg-white/5 rounded-[1.5rem] p-5">
                                <h4 className="font-bold text-slate-900 dark:text-white mb-3">语法提示</h4>
                                <div className="text-xs text-slate-500 dark:text-text-secondary leading-6 space-y-1.5">
                                    <div className="flex items-center gap-2"><span className="font-mono text-accent-coral">@</span><span>一级章节</span></div>
                                    <div className="flex items-center gap-2"><span className="font-mono text-cyan-500">@@</span><span>二级知识点</span></div>
                                    <div className="flex items-center gap-2"><span className="font-mono text-emerald-500">{'{}'}</span><span>具体内容（可挂一级/二级，可多个）</span></div>
                                </div>
                            </div>
                        </div>
                    )}

                    {inputMode === 'visual' && (
                        <div className="flex flex-col gap-5">
                            {chapters.map((chapter, chapterIndex) => (
                                <section key={chapter.id} className="rounded-3xl bg-gradient-to-br from-slate-50 to-blue-50/70 dark:from-white/5 dark:to-[#0B1220]/55 p-6 shadow-sm">
                                    <div className="flex items-center gap-3 mb-4">
                                        <span className="inline-flex items-center gap-2 text-xs font-bold text-slate-400 uppercase tracking-wider">
                                            <span className="size-2 rounded-full bg-blue-500"></span>
                                            章节 {chapterIndex + 1}
                                        </span>
                                        <input
                                            value={chapter.title}
                                            onChange={(e) => {
                                                const nextTitle = e.target.value;
                                                updateChapter(chapter.id, (old) => ({ ...old, title: nextTitle }));
                                                if (nextTitle.trim()) {
                                                    setChapterTitleErrors((prev) => {
                                                        if (!prev[chapter.id]) return prev;
                                                        const next = { ...prev };
                                                        delete next[chapter.id];
                                                        return next;
                                                    });
                                                }
                                            }}
                                            placeholder="例如：计算机网络概述"
                                            readOnly={restrictToSingleChapter || restrictToSinglePoint}
                                            className={`flex-1 border-0 ring-0 outline-none shadow-none rounded-xl px-4 py-3 text-slate-900 dark:text-white placeholder:text-slate-500/80 dark:placeholder:text-slate-400 focus:border-0 focus:outline-none focus:ring-2 transition-all ${
                                                chapterTitleErrors[chapter.id]
                                                    ? 'bg-red-50 dark:bg-red-500/10 focus:ring-red-400/45'
                                                    : 'bg-blue-100/80 dark:bg-[#11213a]/85 focus:ring-blue-400/35'
                                            } ${restrictToSingleChapter || restrictToSinglePoint ? 'cursor-not-allowed opacity-90' : ''}`}
                                        />
                                        {!(restrictToSingleChapter || restrictToSinglePoint) && (
                                            <button
                                                onClick={() => removeChapter(chapter.id)}
                                                className="px-3 py-2 rounded-xl text-red-500 hover:bg-red-500/10 text-sm font-bold"
                                            >
                                                删除
                                            </button>
                                        )}
                                    </div>
                                    {chapterTitleErrors[chapter.id] && (
                                        <p className="mt-1 mb-2 ml-1 text-xs font-medium text-red-500">
                                            请填写章节标题，否则该章节内容无法添加
                                        </p>
                                    )}

                                    <div className="space-y-4">
                                        {!restrictToSinglePoint && (
                                            <div className="rounded-2xl bg-white/85 dark:bg-[#111827]/60 p-4 md:p-5 shadow-sm">
                                            <div className="flex items-center justify-between gap-3 mb-3">
                                                <span className="inline-flex items-center gap-2 text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                                                    <span className="size-1.5 rounded-full bg-emerald-400"></span>
                                                    章节直连内容（可选）
                                                </span>
                                                <button
                                                    onClick={() => addChapterArticle(chapter.id)}
                                                    className="px-3 py-2 rounded-full bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 hover:bg-emerald-500/20 text-xs font-bold"
                                                >
                                                    + 添加一级内容
                                                </button>
                                            </div>

                                            {chapter.articles.length === 0 ? (
                                                <div className="rounded-xl bg-slate-50/80 dark:bg-white/5 p-4 text-sm text-slate-500 dark:text-slate-400">
                                                    当前没有一级内容。你可以直接添加内容，或使用二级层级组织知识点。
                                                </div>
                                            ) : (
                                                <>
                                                    <div className="flex flex-wrap items-center gap-2 mb-3">
                                                        {chapter.articles.map((article, articleIndex) => {
                                                            const currentActiveId = activeChapterArticleByChapter[chapter.id] || chapter.articles[0]?.id;
                                                            const isActive = currentActiveId === article.id;
                                                            return (
                                                                <button
                                                                    key={article.id}
                                                                    onClick={() =>
                                                                        setActiveChapterArticleByChapter((prev) => ({
                                                                            ...prev,
                                                                            [chapter.id]: article.id
                                                                        }))
                                                                    }
                                                                    className={`px-3 py-1.5 rounded-full text-xs font-bold transition-colors ${
                                                                        isActive
                                                                            ? 'bg-primary text-white'
                                                                            : 'bg-white dark:bg-background-dark text-slate-500 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white'
                                                                    }`}
                                                                >
                                                                    {article.title.trim() || `章节内容 ${articleIndex + 1}`}
                                                                </button>
                                                            );
                                                        })}
                                                    </div>

                                                    {(() => {
                                                        const currentActiveId = activeChapterArticleByChapter[chapter.id] || chapter.articles[0]?.id;
                                                        const activeChapterArticle =
                                                            chapter.articles.find((a) => a.id === currentActiveId) || chapter.articles[0];
                                                        if (!activeChapterArticle) return null;
                                                        return (
                                                            <div className="space-y-2">
                                                                <div className="flex items-center gap-3">
                                                                    <input
                                                                        value={activeChapterArticle.title}
                                                                        onChange={(e) =>
                                                                            updateChapter(chapter.id, (old) => ({
                                                                                ...old,
                                                                                articles: old.articles.map((a) =>
                                                                                    a.id === activeChapterArticle.id
                                                                                        ? { ...a, title: e.target.value }
                                                                                        : a
                                                                                )
                                                                            }))
                                                                        }
                                                                        placeholder="章节内容标题（用于切换展示）"
                                                                        className="flex-1 border-0 ring-0 outline-none shadow-none bg-blue-100/80 dark:bg-[#11213a]/85 rounded-lg px-3 py-2 text-slate-900 dark:text-white focus:border-0 focus:outline-none focus:ring-2 focus:ring-blue-400/35"
                                                                    />
                                                                    <button
                                                                        onClick={() => removeChapterArticle(chapter.id, activeChapterArticle.id)}
                                                                        className="px-2.5 py-1.5 rounded-lg text-red-500 hover:bg-red-500/10 text-xs font-bold"
                                                                    >
                                                                        删除
                                                                    </button>
                                                                </div>
                                                                <div className="rounded-xl overflow-hidden">
                                                                    <TyporaEditor
                                                                        key={activeChapterArticle.id}
                                                                        initialValue={activeChapterArticle.content}
                                                                        onChange={(nextValue) =>
                                                                            updateChapter(chapter.id, (old) => ({
                                                                                ...old,
                                                                                articles: old.articles.map((a) =>
                                                                                    a.id === activeChapterArticle.id
                                                                                        ? { ...a, content: nextValue }
                                                                                        : a
                                                                                )
                                                                            }))
                                                                        }
                                                                        placeholder="在这里填写章节直连内容（支持 Markdown）"
                                                                    />
                                                                </div>
                                                            </div>
                                                        );
                                                    })()}
                                                </>
                                            )}
                                        </div>
                                        )}

                                        {chapter.points.length === 0 ? (
                                            <div className="rounded-2xl bg-white/70 dark:bg-[#0F172A]/30 p-4 text-sm text-slate-500 dark:text-slate-400">
                                                当前没有二级层级。若需要更细分知识点，可点击下方按钮添加。
                                            </div>
                                        ) : chapter.points.map((point, pointIndex) => (
                                            <article key={point.id} className="rounded-2xl bg-cyan-50/70 dark:bg-[#062030]/45 p-4 md:p-5 shadow-sm">
                                                <div className="flex items-center gap-3">
                                                    <span className="inline-flex items-center gap-2 text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                                                        <span className="size-1.5 rounded-full bg-cyan-400"></span>
                                                        知识点 {pointIndex + 1}
                                                    </span>
                                                    <input
                                                        value={point.title}
                                                        onChange={(e) =>
                                                            updateChapter(chapter.id, (old) => ({
                                                                ...old,
                                                                points: old.points.map((p) =>
                                                                    p.id === point.id ? { ...p, title: e.target.value } : p
                                                                )
                                                            }))
                                                        }
                                                        readOnly={restrictToSinglePoint}
                                                        placeholder="例如：网络分层与体系结构"
                                                        className={`flex-1 border-0 ring-0 outline-none shadow-none bg-cyan-100/70 dark:bg-[#0c2636]/85 rounded-xl px-4 py-2.5 text-slate-900 dark:text-white placeholder:text-slate-500/80 dark:placeholder:text-slate-400 focus:border-0 focus:outline-none focus:ring-2 focus:ring-cyan-400/35 ${restrictToSinglePoint ? 'cursor-not-allowed opacity-90' : ''}`}
                                                    />
                                                    {!restrictToSinglePoint && (
                                                        <button
                                                            onClick={() => removePoint(chapter.id, point.id)}
                                                            className="px-3 py-2 rounded-xl text-red-500 hover:bg-red-500/10 text-sm font-bold"
                                                        >
                                                            删除
                                                        </button>
                                                    )}
                                                </div>

                                                <div className="mt-4 bg-slate-50/85 dark:bg-white/5 rounded-xl p-3">
                                                    <div className="flex flex-wrap items-center gap-2 mb-3">
                                                        {point.articles.map((article, articleIndex) => {
                                                            const currentActiveId = activeArticleByPoint[point.id] || point.articles[0]?.id;
                                                            const isActive = currentActiveId === article.id;
                                                            return (
                                                                <button
                                                                    key={article.id}
                                                                    onClick={() =>
                                                                        setActiveArticleByPoint((prev) => ({
                                                                            ...prev,
                                                                            [point.id]: article.id
                                                                        }))
                                                                    }
                                                                    className={`px-3 py-1.5 rounded-full text-xs font-bold transition-colors ${
                                                                        isActive
                                                                            ? 'bg-primary text-white'
                                                                            : 'bg-white dark:bg-background-dark text-slate-500 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white'
                                                                    }`}
                                                                >
                                                                    {article.title.trim() || `内容 ${articleIndex + 1}`}
                                                                </button>
                                                            );
                                                        })}
                                                    </div>

                                                    {(() => {
                                                        const currentActiveId = activeArticleByPoint[point.id] || point.articles[0]?.id;
                                                        const activeArticle =
                                                            point.articles.find((a) => a.id === currentActiveId) || point.articles[0];
                                                        if (!activeArticle) {
                                                            return (
                                                                <div className="rounded-xl bg-white/80 dark:bg-background-dark/40 p-4 text-sm text-slate-500 dark:text-slate-400">
                                                                    当前二级层级没有内容，点击下方“添加内容”即可创建。
                                                                </div>
                                                            );
                                                        }
                                                        return (
                                                            <div className="space-y-2">
                                                                <div className="flex items-center gap-3">
                                                                    <span className="inline-flex items-center gap-2 text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                                                                        <span className="size-1.5 rounded-full bg-emerald-400"></span>
                                                                        详细内容
                                                                    </span>
                                                                    <input
                                                                        value={activeArticle.title}
                                                                        onChange={(e) =>
                                                                            updateChapter(chapter.id, (old) => ({
                                                                                ...old,
                                                                                points: old.points.map((p) =>
                                                                                    p.id !== point.id
                                                                                        ? p
                                                                                        : {
                                                                                              ...p,
                                                                                              articles: p.articles.map((a) =>
                                                                                                  a.id === activeArticle.id
                                                                                                      ? { ...a, title: e.target.value }
                                                                                                      : a
                                                                                              )
                                                                                          }
                                                                                )
                                                                            }))
                                                                        }
                                                                        placeholder="内容标题（用于切换展示）"
                                                                        className="flex-1 border-0 ring-0 outline-none shadow-none bg-white/95 dark:bg-background-dark/90 rounded-lg px-3 py-2 text-slate-900 dark:text-white focus:border-0 focus:outline-none focus:ring-2 focus:ring-primary/40"
                                                                    />
                                                                    <button
                                                                        onClick={() => removeArticle(chapter.id, point.id, activeArticle.id)}
                                                                        className="px-2.5 py-1.5 rounded-lg text-red-500 hover:bg-red-500/10 text-xs font-bold"
                                                                    >
                                                                        删除
                                                                    </button>
                                                                </div>
                                                                <div className="rounded-xl overflow-hidden">
                                                                    <TyporaEditor
                                                                        key={activeArticle.id}
                                                                        initialValue={activeArticle.content}
                                                                        onChange={(nextValue) =>
                                                                            updateChapter(chapter.id, (old) => ({
                                                                                ...old,
                                                                                points: old.points.map((p) =>
                                                                                    p.id !== point.id
                                                                                        ? p
                                                                                        : {
                                                                                              ...p,
                                                                                              articles: p.articles.map((a) =>
                                                                                                  a.id === activeArticle.id
                                                                                                      ? { ...a, content: nextValue }
                                                                                                      : a
                                                                                              )
                                                                                          }
                                                                                )
                                                                            }))
                                                                        }
                                                                        placeholder="在这里填写该内容的详细正文（支持 Markdown）"
                                                                    />
                                                                </div>
                                                            </div>
                                                        );
                                                    })()}
                                                </div>

                                                <div className="flex justify-end">
                                                    <button
                                                        onClick={() => addArticle(chapter.id, point.id)}
                                                        className="px-3 py-2 rounded-full bg-primary/10 text-primary hover:bg-primary/20 text-xs font-bold"
                                                    >
                                                        + 添加内容
                                                    </button>
                                                </div>
                                            </article>
                                        ))}
                                        {!restrictToSinglePoint && (
                                            <div className="flex justify-end">
                                                <button
                                                    onClick={() => addPoint(chapter.id)}
                                                    className="px-4 py-2 rounded-full bg-cyan-500/10 text-cyan-600 dark:text-cyan-400 hover:bg-cyan-500/20 text-sm font-bold"
                                                >
                                                    + 添加知识点（可选）
                                                </button>
                                            </div>
                                        )}
                                    </div>
                                </section>
                            ))}

                            <div className="flex items-center justify-between">
                                {!(restrictToSingleChapter || restrictToSinglePoint) ? (
                                    <button
                                        onClick={addChapter}
                                        className="px-5 py-2.5 rounded-full bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 hover:bg-emerald-500/20 text-sm font-bold"
                                    >
                                        + 添加章节
                                    </button>
                                ) : (
                                    <span className="text-xs text-slate-400">
                                        {restrictToSinglePoint ? '你正在为当前知识点补充多个详细内容' : '你正在为当前章节补充内容'}
                                    </span>
                                )}
                                <div className="text-xs text-slate-400">提交时自动转换为 DSL；章节直连内容会直接挂在章节下显示</div>
                            </div>
                        </div>
                    )}

                    <div className="flex items-center justify-end gap-4 mt-2 pt-5 border-t border-slate-200 dark:border-white/5">
                        <button
                            onClick={onClose}
                            className="px-8 py-3 rounded-full border border-slate-300 dark:border-slate-600 text-slate-500 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-white/5 hover:text-slate-900 dark:hover:text-white transition-all font-medium text-sm"
                        >
                            取消
                        </button>
                        <button
                            onClick={handleSubmit}
                            className="group px-8 py-3 rounded-full bg-primary text-white hover:bg-blue-600 shadow-lg hover:-translate-y-0.5 transition-all font-bold flex items-center gap-2 text-sm"
                        >
                            <span className="material-symbols-outlined text-[20px]">save</span>
                            {isAppendMode ? '添加到当前科目' : '创建科目'}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default AddSubjectModal;
