import React, { useState, useEffect, useRef } from 'react';
import ReactMarkdown from 'react-markdown';

interface EditArticleModalProps {
    article: { id: string; title: string; body: string } | null;
    onClose: () => void;
    onSave: (id: string, title: string, content: string) => Promise<void>;
}

const EditArticleModal: React.FC<EditArticleModalProps> = ({ article, onClose, onSave }) => {
    const [title, setTitle] = useState('');
    const [content, setContent] = useState('');
    const [loading, setLoading] = useState(false);
    const [showPreview, setShowPreview] = useState(false); // For mobile/toggle
    const textareaRef = useRef<HTMLTextAreaElement>(null);

    useEffect(() => {
        if (article) {
            setTitle(article.title);
            setContent(article.body);
        }
    }, [article]);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!article) return;
        
        setLoading(true);
        try {
            await onSave(article.id, title, content);
            onClose();
        } catch (error) {
            console.error(error);
        } finally {
            setLoading(false);
        }
    };

    const insertText = (before: string, after: string = '') => {
        const textarea = textareaRef.current;
        if (!textarea) return;

        const start = textarea.selectionStart;
        const end = textarea.selectionEnd;
        const selectedText = content.substring(start, end);
        
        const newText = content.substring(0, start) + before + selectedText + after + content.substring(end);
        setContent(newText);
        
        // Restore focus and selection
        setTimeout(() => {
            textarea.focus();
            textarea.setSelectionRange(start + before.length, end + before.length);
        }, 0);
    };

    const tools = [
        { icon: 'format_bold', label: 'Bold', action: () => insertText('**', '**') },
        { icon: 'format_italic', label: 'Italic', action: () => insertText('*', '*') },
        { icon: 'format_h1', label: 'H1', action: () => insertText('# ') },
        { icon: 'format_h2', label: 'H2', action: () => insertText('## ') },
        { icon: 'format_list_bulleted', label: 'List', action: () => insertText('- ') },
        { icon: 'code_blocks', label: 'Code', action: () => insertText('```\n', '\n```') },
        { icon: 'link', label: 'Link', action: () => insertText('[', '](url)') },
        { icon: 'format_quote', label: 'Quote', action: () => insertText('> ') },
    ];

    if (!article) return null;

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm animate-fade-in">
            <div className="bg-white dark:bg-surface-dark w-full max-w-7xl rounded-[2rem] shadow-2xl overflow-hidden flex flex-col h-[90vh]">
                {/* Header */}
                <div className="px-8 py-5 border-b border-slate-100 dark:border-white/5 flex justify-between items-center bg-white dark:bg-[#1E293B]">
                    <div className="flex items-center gap-4 flex-1">
                        <h2 className="text-xl font-extrabold text-slate-900 dark:text-white flex items-center gap-2">
                            <span className="material-symbols-outlined text-primary">edit_document</span>
                            编辑文章
                        </h2>
                        <input 
                            type="text" 
                            value={title}
                            onChange={(e) => setTitle(e.target.value)}
                            className="flex-1 max-w-md bg-slate-50 dark:bg-white/5 border border-slate-200 dark:border-white/10 rounded-xl px-4 py-2 text-base font-bold text-slate-900 dark:text-white focus:outline-none focus:border-primary transition-colors"
                            placeholder="文章标题"
                            required
                        />
                    </div>
                    <button onClick={onClose} className="text-slate-400 hover:text-slate-600 dark:hover:text-white transition-colors p-2 hover:bg-slate-100 dark:hover:bg-white/5 rounded-full">
                        <span className="material-symbols-outlined">close</span>
                    </button>
                </div>
                
                {/* Toolbar */}
                <div className="px-6 py-2 border-b border-slate-100 dark:border-white/5 bg-slate-50/50 dark:bg-[#0F172A]/50 flex items-center gap-1 overflow-x-auto">
                    {tools.map((tool, idx) => (
                        <button
                            key={idx}
                            type="button"
                            onClick={tool.action}
                            className="p-2 rounded-lg text-slate-500 dark:text-slate-400 hover:bg-white dark:hover:bg-white/10 hover:text-primary dark:hover:text-white transition-all flex flex-col items-center gap-1 min-w-[3rem]"
                            title={tool.label}
                        >
                            <span className="material-symbols-outlined text-[20px]">{tool.icon}</span>
                        </button>
                    ))}
                    <div className="w-px h-6 bg-slate-200 dark:bg-white/10 mx-2"></div>
                    <button 
                        onClick={() => setShowPreview(!showPreview)}
                        className={`p-2 rounded-lg transition-all flex items-center gap-2 px-3 text-sm font-bold md:hidden ${showPreview ? 'bg-primary text-white' : 'text-slate-500 hover:bg-slate-200'}`}
                    >
                        <span className="material-symbols-outlined text-[18px]">visibility</span>
                        {showPreview ? '编辑' : '预览'}
                    </button>
                    <span className="hidden md:flex text-xs text-slate-400 font-medium ml-auto">Markdown Supported</span>
                </div>

                {/* Editor Body (Split View) */}
                <div className="flex-1 flex overflow-hidden">
                    {/* Left: Editor */}
                    <div className={`flex-1 flex flex-col h-full ${showPreview ? 'hidden md:flex' : 'flex'}`}>
                        <textarea 
                            ref={textareaRef}
                            value={content}
                            onChange={(e) => setContent(e.target.value)}
                            className="w-full h-full p-8 bg-white dark:bg-[#0F172A] text-base text-slate-700 dark:text-slate-300 font-mono focus:outline-none resize-none leading-relaxed"
                            placeholder="# Start writing..."
                            spellCheck={false}
                        />
                    </div>

                    {/* Divider */}
                    <div className="hidden md:block w-px bg-slate-200 dark:bg-white/5"></div>

                    {/* Right: Preview */}
                    <div className={`flex-1 bg-slate-50 dark:bg-[#0B1120] overflow-y-auto p-8 ${showPreview ? 'flex' : 'hidden md:flex'}`}>
                        <div className="prose prose-slate dark:prose-invert max-w-none w-full prose-headings:font-bold prose-h1:text-3xl prose-h2:text-2xl prose-a:text-primary prose-code:text-primary prose-code:bg-primary/10 prose-code:px-1 prose-code:rounded prose-pre:bg-slate-900 prose-pre:dark:bg-[#1E293B]">
                            <h1 className="mb-8">{title}</h1>
                            <ReactMarkdown>{content}</ReactMarkdown>
                        </div>
                    </div>
                </div>

                {/* Footer */}
                <div className="p-5 border-t border-slate-100 dark:border-white/5 bg-white dark:bg-[#1E293B] flex justify-between items-center z-10">
                    <div className="text-xs text-slate-400 hidden sm:block">
                        {content.length} characters
                    </div>
                    <div className="flex gap-3 ml-auto">
                        <button 
                            type="button" 
                            onClick={onClose}
                            className="px-6 py-2.5 rounded-xl font-bold text-slate-500 hover:bg-slate-100 dark:hover:bg-white/5 transition-colors"
                        >
                            Cancel
                        </button>
                        <button 
                            onClick={handleSubmit}
                            disabled={loading}
                            className="px-6 py-2.5 rounded-xl font-bold bg-primary text-white hover:opacity-90 transition-opacity shadow-lg shadow-primary/20 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                        >
                            {loading ? 'Saving...' : 'Save Changes'}
                            {!loading && <span className="material-symbols-outlined text-[18px]">save</span>}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default EditArticleModal;
