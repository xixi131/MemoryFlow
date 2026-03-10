import React from 'react';
import ReactMarkdown from 'react-markdown';

interface MarkdownRendererProps {
    content: string;
    className?: string;
}

const defaultClassName =
    'prose prose-slate dark:prose-invert max-w-none prose-headings:font-bold prose-h1:text-3xl prose-h2:text-2xl prose-h3:text-xl prose-a:text-primary prose-code:text-primary prose-code:bg-primary/10 prose-code:px-1 prose-code:rounded prose-pre:bg-slate-900 prose-pre:dark:bg-[#0B1120] prose-pre:border prose-pre:border-white/10';

const MarkdownRenderer: React.FC<MarkdownRendererProps> = ({ content, className }) => {
    return (
        <div className={className || defaultClassName}>
            <ReactMarkdown>{content}</ReactMarkdown>
        </div>
    );
};

export default MarkdownRenderer;
