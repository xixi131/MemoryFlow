import React, { useEffect, useRef, useState } from 'react';
import { Editor, defaultValueCtx, editorViewOptionsCtx, rootCtx } from '@milkdown/core';
import { commonmark } from '@milkdown/preset-commonmark';
import { gfm } from '@milkdown/preset-gfm';
import { Milkdown, MilkdownProvider, useEditor } from '@milkdown/react';
import { history } from '@milkdown/plugin-history';
import { listener, listenerCtx } from '@milkdown/plugin-listener';
import { prism } from '@milkdown/plugin-prism';
import { nord } from '@milkdown/theme-nord';

import '@milkdown/theme-nord/style.css';
import 'prismjs/themes/prism.css';
import './TyporaEditor.css';

export interface TyporaEditorProps {
    /** 初始 Markdown 内容 */
    initialValue?: string;
    /** 内容变化时的回调函数，返回最新的 Markdown 字符串 */
    onChange?: (markdown: string) => void;
    /** 编辑器只读状态 */
    readOnly?: boolean;
    /** 占位符提示 */
    placeholder?: string;
    /** 额外容器样式 */
    className?: string;
    /** 扁平化样式（无阴影、无额外背景） */
    flat?: boolean;
}

const TyporaEditorInner: React.FC<TyporaEditorProps> = ({
    initialValue = '',
    onChange,
    readOnly = false,
    placeholder = '在这里输入 Markdown 内容...',
    className,
    flat = false
}) => {
    // Important: initial value only used during first initialization to avoid cursor reset.
    const initialValueRef = useRef(initialValue);
    const onChangeRef = useRef(onChange);
    const lastMarkdownRef = useRef(initialValueRef.current);

    const [focused, setFocused] = useState(false);
    const [empty, setEmpty] = useState(initialValueRef.current.trim().length === 0);

    useEffect(() => {
        onChangeRef.current = onChange;
    }, [onChange]);

    const editorInfo = useEditor(
        (root) =>
            Editor.make()
                .config(nord)
                .config((ctx) => {
                    ctx.set(rootCtx, root);
                    ctx.set(defaultValueCtx, initialValueRef.current);
                    ctx.update(editorViewOptionsCtx, (prev) => ({
                        ...prev,
                        editable: () => !readOnly
                    }));

                    const listenerApi = ctx.get(listenerCtx);
                    listenerApi.focus(() => setFocused(true));
                    listenerApi.blur(() => setFocused(false));
                    listenerApi.markdownUpdated((_, markdown) => {
                        if (markdown === lastMarkdownRef.current) return;
                        lastMarkdownRef.current = markdown;
                        setEmpty(markdown.trim().length === 0);
                        onChangeRef.current?.(markdown);
                    });
                })
                .use(commonmark)
                .use(gfm)
                .use(prism)
                .use(history)
                .use(listener),
        []
    );

    useEffect(() => {
        // Sync read-only status without recreating editor instance.
        editorInfo.get()?.action((ctx) => {
            ctx.update(editorViewOptionsCtx, (prev) => ({
                ...prev,
                editable: () => !readOnly
            }));
        });
    }, [readOnly, editorInfo]);

    return (
        <div className={`typora-editor-shell ${flat ? 'typora-editor-shell-flat' : ''} ${className || ''}`.trim()}>
            {!readOnly && empty && !focused && (
                <div className="typora-editor-placeholder">{placeholder}</div>
            )}
            <Milkdown />
        </div>
    );
};

const TyporaEditor: React.FC<TyporaEditorProps> = (props) => {
    return (
        <MilkdownProvider>
            <TyporaEditorInner {...props} />
        </MilkdownProvider>
    );
};

export default TyporaEditor;
