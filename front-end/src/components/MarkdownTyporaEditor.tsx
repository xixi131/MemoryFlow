import React, { useEffect, useMemo, useRef, useState } from 'react';

interface MarkdownTyporaEditorProps {
    value: string;
    onChange: (value: string) => void;
    placeholder?: string;
    minHeightClassName?: string;
    className?: string;
    externalTextareaRef?: React.RefObject<HTMLTextAreaElement | null>;
}

const H1_MARK = '\u200B';
const H2_MARK = '\u200C';
const H3_MARK = '\u200D';

const isHeadingLine = (line: string) =>
    line.startsWith(H1_MARK) || line.startsWith(H2_MARK) || line.startsWith(H3_MARK);

const encodeMarkdownToEditor = (markdown: string) =>
    markdown
        .split('\n')
        .map((line) => {
            if (/^###\s+/.test(line)) return `${H3_MARK}${line.replace(/^###\s+/, '')}`;
            if (/^##\s+/.test(line)) return `${H2_MARK}${line.replace(/^##\s+/, '')}`;
            if (/^#\s+/.test(line)) return `${H1_MARK}${line.replace(/^#\s+/, '')}`;
            return line;
        })
        .join('\n');

const decodeEditorToMarkdown = (editorValue: string) =>
    editorValue
        .split('\n')
        .map((line) => {
            if (line.startsWith(H3_MARK)) return `### ${line.slice(1)}`;
            if (line.startsWith(H2_MARK)) return `## ${line.slice(1)}`;
            if (line.startsWith(H1_MARK)) return `# ${line.slice(1)}`;
            return line;
        })
        .join('\n');

const normalizeEditorRaw = (raw: string) =>
    raw
        .split('\n')
        .map((line) => {
            if (/^###\s+/.test(line)) return `${H3_MARK}${line.replace(/^###\s+/, '')}`;
            if (/^##\s+/.test(line)) return `${H2_MARK}${line.replace(/^##\s+/, '')}`;
            if (/^#\s+/.test(line)) return `${H1_MARK}${line.replace(/^#\s+/, '')}`;
            return line;
        })
        .join('\n');

const renderLine = (line: string, idx: number, activeLine: number) => {
    const rowClass = 'min-h-8 flex items-center';
    const isActive = idx === activeLine;
    if (!line.trim()) {
        return <div key={idx} className={rowClass}>&nbsp;</div>;
    }

    if (line.startsWith(H1_MARK)) {
        const text = line.slice(1);
        return (
            <div key={idx} className={`${rowClass} py-1`}>
                {isActive ? <span className="text-slate-400 dark:text-slate-500 select-none whitespace-pre"># </span> : null}
                <span className="text-[28px] leading-8 font-black tracking-tight text-slate-800 dark:text-white">{text}</span>
                {isActive ? <span className="inline-block w-[2px] h-8 ml-0.5 bg-slate-900 dark:bg-slate-100 animate-pulse"></span> : null}
            </div>
        );
    }

    if (line.startsWith(H2_MARK)) {
        const text = line.slice(1);
        return (
            <div key={idx} className={`${rowClass} py-1`}>
                {isActive ? <span className="text-slate-400 dark:text-slate-500 select-none whitespace-pre">## </span> : null}
                <span className="text-[23px] leading-8 font-extrabold text-slate-900 dark:text-white">{text}</span>
                {isActive ? <span className="inline-block w-[2px] h-8 ml-0.5 bg-slate-900 dark:bg-slate-100 animate-pulse"></span> : null}
            </div>
        );
    }

    if (line.startsWith(H3_MARK)) {
        const text = line.slice(1);
        return (
            <div key={idx} className={`${rowClass} py-0.5`}>
                {isActive ? <span className="text-slate-400 dark:text-slate-500 select-none whitespace-pre">### </span> : null}
                <span className="text-[20px] leading-8 font-bold text-slate-800 dark:text-slate-100">{text}</span>
                {isActive ? <span className="inline-block w-[2px] h-7 ml-0.5 bg-slate-900 dark:bg-slate-100 animate-pulse"></span> : null}
            </div>
        );
    }

    const quote = line.match(/^>\s?(.*)$/);
    if (quote) {
        return (
            <div key={idx} className={`${rowClass} text-slate-600 dark:text-slate-300 italic`}>
                <span className="opacity-0 select-none whitespace-pre">&gt; </span>
                <span className="border-l-4 border-primary/40 pl-3 leading-7">{quote[1]}</span>
            </div>
        );
    }

    const unordered = line.match(/^[-*]\s+(.*)$/);
    if (unordered) {
        return (
            <div key={idx} className={`${rowClass} text-slate-700 dark:text-slate-200 leading-7`}>
                <span className="opacity-0 select-none whitespace-pre">- </span>
                <span className="mr-2 -ml-4 text-primary">•</span>
                <span>{unordered[1]}</span>
            </div>
        );
    }

    const ordered = line.match(/^(\d+)\.\s+(.*)$/);
    if (ordered) {
        return (
            <div key={idx} className={`${rowClass} text-slate-700 dark:text-slate-200 leading-7`}>
                <span className="opacity-0 select-none whitespace-pre">{ordered[1]}. </span>
                <span className="mr-2 -ml-7 text-slate-400">{ordered[1]}.</span>
                <span>{ordered[2]}</span>
            </div>
        );
    }

    return <p key={idx} className={`${rowClass} text-slate-700 dark:text-slate-200 leading-7 whitespace-pre-wrap`}>{line}</p>;
};

const MarkdownTyporaEditor: React.FC<MarkdownTyporaEditorProps> = ({
    value,
    onChange,
    placeholder = '# 第一章',
    minHeightClassName = 'min-h-[140px]',
    className = '',
    externalTextareaRef
}) => {
    const textareaRef = useRef<HTMLTextAreaElement>(null);
    const previewRef = useRef<HTMLDivElement>(null);
    const [editorValue, setEditorValue] = useState(() => encodeMarkdownToEditor(value));
    const [activeLine, setActiveLine] = useState(0);

    useEffect(() => {
        const encoded = encodeMarkdownToEditor(value);
        if (encoded !== editorValue) {
            setEditorValue(encoded);
        }
    }, [value, editorValue]);

    const lines = useMemo(() => editorValue.split('\n'), [editorValue]);

    const syncScroll = () => {
        if (!textareaRef.current || !previewRef.current) return;
        previewRef.current.scrollTop = textareaRef.current.scrollTop;
        previewRef.current.scrollLeft = textareaRef.current.scrollLeft;
    };

    const getLineFromPos = (text: string, pos: number) => text.slice(0, pos).split('\n').length - 1;
    const getLineRangeByIndex = (text: string, lineIndex: number) => {
        const textLines = text.split('\n');
        let start = 0;
        for (let i = 0; i < lineIndex; i += 1) {
            start += (textLines[i]?.length || 0) + 1;
        }
        const lineText = textLines[lineIndex] || '';
        return { start, end: start + lineText.length, text: lineText };
    };

    const syncActiveLineFromSelection = () => {
        if (!textareaRef.current) return;
        const pos = textareaRef.current.selectionStart || 0;
        const nextLine = getLineFromPos(editorValue, pos);
        setActiveLine(nextLine);

        const { end, text } = getLineRangeByIndex(editorValue, nextLine);
        if (isHeadingLine(text)) {
            if (textareaRef.current.selectionStart !== end || textareaRef.current.selectionEnd !== end) {
                textareaRef.current.setSelectionRange(end, end);
            }
        }
    };

    const activeLineText = lines[activeLine] || '';
    const isActiveHeading = isHeadingLine(activeLineText);

    return (
        <div className={`relative rounded-xl bg-white dark:bg-background-dark/90 ${minHeightClassName} ${className}`}>
            <div
                ref={previewRef}
                className={`absolute inset-0 overflow-auto px-4 py-3 pointer-events-none ${minHeightClassName}`}
                aria-hidden
            >
                {editorValue.trim().length === 0 ? (
                    <p className="text-slate-400 dark:text-slate-500 leading-8">{placeholder}</p>
                ) : (
                    <div>{lines.map((line, idx) => renderLine(line, idx, activeLine))}</div>
                )}
            </div>
            <textarea
                ref={(node) => {
                    textareaRef.current = node;
                    if (externalTextareaRef) {
                        externalTextareaRef.current = node;
                    }
                }}
                value={editorValue}
                onChange={(e) => {
                    const raw = e.target.value;
                    const start = e.target.selectionStart || 0;
                    const normalized = normalizeEditorRaw(raw);
                    const normalizedBefore = normalizeEditorRaw(raw.slice(0, start));

                    setEditorValue(normalized);
                    onChange(decodeEditorToMarkdown(normalized));

                    requestAnimationFrame(() => {
                        if (!textareaRef.current) return;
                        const nextPos = normalizedBefore.length;
                        const line = getLineFromPos(normalized, nextPos);
                        const { end, text } = getLineRangeByIndex(normalized, line);
                        const cursor = isHeadingLine(text) ? end : nextPos;
                        textareaRef.current.setSelectionRange(cursor, cursor);
                        setActiveLine(line);
                    });
                }}
                onScroll={syncScroll}
                onSelect={syncActiveLineFromSelection}
                onClick={syncActiveLineFromSelection}
                onFocus={syncActiveLineFromSelection}
                onKeyUp={syncActiveLineFromSelection}
                spellCheck={false}
                className={`relative z-10 w-full resize-y bg-transparent px-4 py-3 text-base leading-8 focus:outline-none ${isActiveHeading ? 'caret-transparent' : 'caret-slate-900 dark:caret-slate-200'} selection:bg-slate-300/45 dark:selection:bg-slate-500/40 selection:text-transparent ${minHeightClassName}`}
                style={{ color: 'transparent', WebkitTextFillColor: 'transparent' }}
            />
        </div>
    );
};

export default MarkdownTyporaEditor;
