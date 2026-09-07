import React, { useEffect, useRef } from 'react';
import { Annotation, Compartment, EditorState } from '@codemirror/state';
import { Decoration, type DecorationSet, drawSelection, EditorView, keymap, placeholder as editorPlaceholder, ViewPlugin, type ViewUpdate, WidgetType } from '@codemirror/view';
import { defaultKeymap, history, historyKeymap } from '@codemirror/commands';
import { bracketMatching } from '@codemirror/language';
import { markdown } from '@codemirror/lang-markdown';
import { searchKeymap } from '@codemirror/search';
import './MarkdownRenderer.css';

interface InlineMarkdownEditorProps { value: string; onChange: (value: string) => void; readOnly?: boolean; placeholder?: string; }
const externalValueUpdate = Annotation.define<boolean>();

const sourceMark = Decoration.mark({ class: 'cm-markdown-source-mark' });
const hiddenSyntax = Decoration.mark({ class: 'cm-markdown-hidden-syntax' });
const strongMark = Decoration.mark({ class: 'cm-markdown-strong' });
const emphasisMark = Decoration.mark({ class: 'cm-markdown-emphasis' });
const strikeMark = Decoration.mark({ class: 'cm-markdown-strike' });
const codeMark = Decoration.mark({ class: 'cm-markdown-inline-code' });

class ImageWidget extends WidgetType {
    constructor(private readonly alt: string, private readonly src: string) { super(); }
    eq(other: ImageWidget) { return other.alt === this.alt && other.src === this.src; }
    toDOM() {
        const image = document.createElement('img');
        image.className = 'cm-markdown-image'; image.src = this.src; image.alt = this.alt; image.loading = 'lazy';
        return image;
    }
}

class ListWidget extends WidgetType {
    constructor(private readonly marker: string) { super(); }
    eq(other: ListWidget) { return other.marker === this.marker; }
    toDOM() {
        const span = document.createElement('span'); span.className = 'cm-markdown-list-marker'; span.textContent = /^\d/.test(this.marker) ? this.marker : '•';
        return span;
    }
}
class LinkWidget extends WidgetType {
    constructor(private readonly label: string, private readonly href: string) { super(); }
    eq(other: LinkWidget) { return other.label === this.label && other.href === this.href; }
    toDOM() {
        const anchor = document.createElement('a');
        anchor.className = 'cm-markdown-link'; anchor.href = this.href; anchor.target = '_blank'; anchor.rel = 'noopener noreferrer'; anchor.textContent = this.label;
        return anchor;
    }
}

type Range = { from: number; to: number; decoration: Decoration };

type ProtectedRange = { from: number; to: number };

const getProtectedMarkdownRanges = (doc: EditorState['doc']): ProtectedRange[] => {
    const ranges: ProtectedRange[] = [];
    // Links are intentionally not protected: deleting their syntax should reveal
    // the raw Markdown naturally. Images remain protected to keep logos stable.
    const imagePattern = /!\[[^\]]*\]\((https?:\/\/[^\s)]+)(?:\s+["'][^"']*["'])?\)/g;
    for (let lineNumber = 1; lineNumber <= doc.lines; lineNumber += 1) {
        const line = doc.line(lineNumber);
        let match: RegExpExecArray | null;
        while ((match = imagePattern.exec(line.text)) !== null) {
            ranges.push({ from: line.from + match.index, to: line.from + match.index + match[0].length });
        }
    }
    return ranges;
};

const protectMarkdownStructure = EditorState.transactionFilter.of((transaction) => {
    if (!transaction.docChanged || transaction.startState.readOnly || transaction.annotation(externalValueUpdate)) return transaction;
    const protectedRanges = getProtectedMarkdownRanges(transaction.startState.doc);
    let touchesProtectedText = false;
    transaction.changes.iterChangedRanges((fromA, toA) => {
        if (touchesProtectedText) return;
        touchesProtectedText = protectedRanges.some(({ from, to }) => {
            if (fromA === toA) return fromA > from && fromA < to;
            return fromA < to && toA > from;
        });
    });
    return touchesProtectedText ? [] : transaction;
});

const addRange = (ranges: Range[], from: number, to: number, decoration: Decoration) => {
    if (to > from) ranges.push({ from, to, decoration });
};

const addInlineDecorations = (
    text: string,
    base: number,
    active: boolean,
    renderWidgets: boolean,
    ranges: Range[],
) => {
    const occupied: Array<[number, number]> = [];
    const free = (from: number, to: number) => occupied.every(([start, end]) => to <= start || from >= end);
    const reserve = (from: number, to: number) => occupied.push([from, to]);
    const syntax = active ? sourceMark : hiddenSyntax;
    const markSyntax = (from: number, to: number) => addRange(ranges, base + from, base + to, syntax);
    const patterns: Array<{ regex: RegExp; render: (match: RegExpExecArray) => void }> = [
        { regex: /(!\[)([^\]]*)\]\((https?:\/\/[^\s)]+)(?:\s+["'][^"']*["'])?\)/g, render: (match) => {
            const start = match.index; const end = start + match[0].length; if (!free(start, end)) return; reserve(start, end);
            // Keep the image rendered on every line, including inactive editable lines.
            ranges.push({ from: base + start, to: base + start, decoration: Decoration.widget({ widget: new ImageWidget(match[2], match[3]), side: -1, ignoreEvent: true }) });
            addRange(ranges, base + start, base + end, hiddenSyntax);
        } },
        { regex: /(\[)([^\]]+)(\]\()([^\s)]+)(\))/g, render: (match) => {
            const start = match.index; const end = start + match[0].length; if (!free(start, end)) return; reserve(start, end);
            const labelStart = start + 1; const labelEnd = labelStart + match[2].length;
            if (!active && renderWidgets) {
                ranges.push({ from: base + start, to: base + start, decoration: Decoration.widget({ widget: new LinkWidget(match[2], match[4]), side: -1 }) });
                markSyntax(start, end);
            } else {
                const linkDecoration = Decoration.mark({ class: 'cm-markdown-link', attributes: { 'data-href': match[4], role: 'link' } });
                // Only the selected line exposes the link source. The URL remains editable
                // once exposed, while inactive lines keep the rendered reading appearance.
                const linkSyntax = active ? sourceMark : hiddenSyntax;
                addRange(ranges, base + start, base + labelStart, linkSyntax);
                addRange(ranges, base + labelStart, base + labelEnd, linkDecoration);
                addRange(ranges, base + labelEnd, base + end, linkSyntax);
            }
        } },
        { regex: /(`+)([^`\n]+?)\1/g, render: (match) => {
            const start = match.index; const end = start + match[0].length; if (!free(start, end)) return; reserve(start, end); const size = match[1].length;
            markSyntax(start, start + size); addRange(ranges, base + start + size, base + end - size, codeMark); markSyntax(end - size, end);
        } },
        { regex: /(\*\*|__)(?=\S)(.+?\S)\1/g, render: (match) => {
            const start = match.index; const end = start + match[0].length; if (!free(start, end)) return; reserve(start, end);
            markSyntax(start, start + 2); addRange(ranges, base + start + 2, base + end - 2, strongMark); markSyntax(end - 2, end);
        } },
        { regex: /(~~)(?=\S)(.+?\S)\1/g, render: (match) => {
            const start = match.index; const end = start + match[0].length; if (!free(start, end)) return; reserve(start, end);
            markSyntax(start, start + 2); addRange(ranges, base + start + 2, base + end - 2, strikeMark); markSyntax(end - 2, end);
        } },
        { regex: /(^|[^\\\w])([*_])(?=\S)(.+?\S)\2(?!\w)/g, render: (match) => {
            const start = match.index + match[1].length; const end = match.index + match[0].length; if (!free(start, end)) return; reserve(start, end);
            markSyntax(start, start + 1); addRange(ranges, base + start + 1, base + end - 1, emphasisMark); markSyntax(end - 1, end);
        } },
    ];
    patterns.forEach(({ regex, render }) => { let match: RegExpExecArray | null; while ((match = regex.exec(text)) !== null) render(match); });
};

const buildDecorations = (view: EditorView): DecorationSet => {
    const ranges: Range[] = [];
    const editable = !view.state.readOnly;
    const selection = view.state.selection.main;
    const anchorLine = view.state.doc.lineAt(selection.anchor).number;
    const headLine = view.state.doc.lineAt(selection.head).number;
    const selectedLineStart = Math.min(anchorLine, headLine);
    const selectedLineEnd = Math.max(anchorLine, headLine);
    for (let number = 1; number <= view.state.doc.lines; number += 1) {
        const line = view.state.doc.line(number);
        const isActive = editable && number >= selectedLineStart && number <= selectedLineEnd;
        const heading = line.text.match(/^(#{1,6})(\s+)/);
        const quote = line.text.match(/^(\s*>+)(\s+)/);
        const list = line.text.match(/^(\s*)([-+*]|\d+[.)])(\s+)/);
        if (heading) {
            ranges.push({ from: line.from, to: line.from, decoration: Decoration.line({ class: `cm-markdown-heading cm-markdown-heading-${heading[1].length}` }) });
            addRange(ranges, line.from, line.from + heading[0].length, isActive ? sourceMark : hiddenSyntax);
        } else if (quote) {
            ranges.push({ from: line.from, to: line.from, decoration: Decoration.line({ class: 'cm-markdown-quote' }) });
            addRange(ranges, line.from, line.from + quote[0].length, isActive ? sourceMark : hiddenSyntax);
        } else if (list) {
            const markerStart = list[1].length; const markerEnd = markerStart + list[2].length + list[3].length;
            ranges.push({ from: line.from, to: line.from, decoration: Decoration.line({ class: 'cm-markdown-list-line' }) });
            addRange(ranges, line.from + markerStart, line.from + markerEnd, isActive ? sourceMark : hiddenSyntax);
        }
        const prefixLength = heading?.[0].length ?? quote?.[0].length ?? list?.[0].length ?? 0;
        addInlineDecorations(line.text.slice(prefixLength), line.from + prefixLength, isActive, !editable, ranges);
        if (list && !isActive) {
            const markerStart = line.from + list[1].length;
            ranges.push({ from: markerStart, to: markerStart, decoration: Decoration.widget({ widget: new ListWidget(list[2]), side: -1, ignoreEvent: true }) });
        }
    }
    ranges.sort((a, b) => a.from - b.from || a.to - b.to);
    return Decoration.set(ranges.map((range) => range.decoration.range(range.from, range.to)), true);
};

const openLinkAtPosition = (event: MouseEvent, view: EditorView) => {
    if (!view.state.readOnly) return false;
    const target = event.target instanceof Element ? event.target.closest<HTMLElement>('.cm-markdown-link[data-href]') : null;
    const directHref = target?.dataset.href;
    if (directHref) {
        const opened = window.open(directHref, '_blank');
        if (opened) opened.opener = null;
        event.preventDefault();
        return true;
    }
    const position = view.posAtCoords({ x: event.clientX, y: event.clientY });
    if (position == null) return false;
    const line = view.state.doc.lineAt(position); const pattern = /\[([^\]]+)\]\((https?:\/\/[^\s)]+)(?:\s+["'][^"']*["'])?\)/g;
    let match: RegExpExecArray | null;
    while ((match = pattern.exec(line.text)) !== null) {
        const start = line.from + match.index; const end = start + match[0].length;
        const labelStart = start + 1;
        const labelEnd = labelStart + match[1].length;
        if (position >= labelStart && position <= labelEnd) { const opened = window.open(match[2], '_blank'); if (opened) opened.opener = null; event.preventDefault(); return true; }
    }
    return false;
};

const placeCaretAtEndOnFirstLineClick = (event: MouseEvent, view: EditorView) => {
    if (view.state.readOnly || event.button !== 0) return false;
    const position = view.posAtCoords({ x: event.clientX, y: event.clientY });
    if (position == null) return false;
    const clickedLine = view.state.doc.lineAt(position);
    const selection = view.state.selection.main;
    const currentLine = view.state.doc.lineAt(selection.head);
    if (selection.empty && clickedLine.number !== currentLine.number) {
        window.requestAnimationFrame(() => {
            const latest = view.state.selection.main;
            if (latest.empty && view.state.doc.lineAt(latest.head).number === clickedLine.number) {
                view.dispatch({ selection: { anchor: clickedLine.to } });
            }
        });
    }
    return false;
};

const livePreview = ViewPlugin.fromClass(class {
    decorations: DecorationSet;
    constructor(view: EditorView) { this.decorations = buildDecorations(view); }
    update(update: ViewUpdate) { this.decorations = buildDecorations(update.view); }
}, { decorations: (plugin) => plugin.decorations });

const InlineMarkdownEditor: React.FC<InlineMarkdownEditorProps> = ({ value, onChange, readOnly = false, placeholder = '输入 Markdown' }) => {
    const hostRef = useRef<HTMLDivElement>(null); const viewRef = useRef<EditorView | null>(null); const onChangeRef = useRef(onChange); const editableCompartmentRef = useRef(new Compartment());
    useEffect(() => { onChangeRef.current = onChange; }, [onChange]);
    useEffect(() => {
        if (!hostRef.current) return;
        const editable = editableCompartmentRef.current;
        const state = EditorState.create({ doc: value, extensions: [history(), protectMarkdownStructure, drawSelection(), bracketMatching(), markdown(), EditorView.lineWrapping, keymap.of([...defaultKeymap, ...historyKeymap, ...searchKeymap]), editorPlaceholder(placeholder), livePreview, editable.of([EditorView.editable.of(!readOnly), EditorState.readOnly.of(readOnly)]), EditorView.domEventHandlers({ mousedown: placeCaretAtEndOnFirstLineClick, click: openLinkAtPosition }), EditorView.updateListener.of((update) => {
            if (!update.docChanged || update.transactions.some((transaction) => transaction.annotation(externalValueUpdate))) return;
            onChangeRef.current(update.state.doc.toString());
        })] });
        const view = new EditorView({ state, parent: hostRef.current }); viewRef.current = view;
        return () => { view.destroy(); viewRef.current = null; };
    }, []);
    useEffect(() => { const view = viewRef.current; if (!view) return; view.dispatch({ effects: editableCompartmentRef.current.reconfigure([EditorView.editable.of(!readOnly), EditorState.readOnly.of(readOnly)]) }); if (readOnly) view.contentDOM.blur(); }, [readOnly]);
    useEffect(() => { const view = viewRef.current; if (!view || view.state.doc.toString() === value) return; view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: value }, annotations: externalValueUpdate.of(true) }); }, [value]);
    return <div ref={hostRef} className={`inline-markdown-editor ${readOnly ? 'is-read-only' : 'is-editable'}`} />;
};

export default InlineMarkdownEditor;
