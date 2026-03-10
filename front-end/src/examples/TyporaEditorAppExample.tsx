import React, { useState } from 'react';
import TyporaEditor from '../components/TyporaEditor';

const initialMarkdown = `# MemoryFlow

## TyporaEditor Demo

输入 \`## 标题\` 然后按空格，会直接变成二级标题。

- 支持列表
- 支持表格
- 支持代码块
`;

const TyporaEditorAppExample: React.FC = () => {
    const [markdown, setMarkdown] = useState(initialMarkdown);

    return (
        <div className="min-h-screen bg-slate-100 dark:bg-[#020617] p-6 md:p-10">
            <div className="mx-auto max-w-5xl space-y-4">
                <h1 className="text-3xl font-black text-slate-900 dark:text-white">TyporaEditor Example</h1>
                <TyporaEditor
                    initialValue={initialMarkdown}
                    onChange={(nextMarkdown) => setMarkdown(nextMarkdown)}
                    placeholder="输入 Markdown..."
                />

                <section className="rounded-2xl bg-white dark:bg-[#0f172a] p-4 border border-slate-200 dark:border-white/10">
                    <h2 className="text-sm font-bold text-slate-500 dark:text-slate-300 mb-2">Current Markdown</h2>
                    <pre className="text-xs leading-6 overflow-auto text-slate-700 dark:text-slate-200 whitespace-pre-wrap">
                        {markdown}
                    </pre>
                </section>
            </div>
        </div>
    );
};

export default TyporaEditorAppExample;
