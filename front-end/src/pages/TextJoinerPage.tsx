import React, { useMemo, useState } from 'react';
import { Check, Copy, WandSparkles, X } from 'lucide-react';
import './TextJoinerPage.css';

type ConverterMode = 'join' | 'gift';

const GIFT_TIERS = [
    { minimum: 10000, label: '远古礼包' },
    { minimum: 5000, label: '神话礼包' },
    { minimum: 4000, label: '传说礼包' },
    { minimum: 3000, label: '史诗礼包' },
    { minimum: 2000, label: '精良礼包' },
    { minimum: 1000, label: '优秀礼包' },
] as const;

const MODE_CONTENT = {
    join: {
        title: '文本转逗号',
        description: '每行一项，转换成一行数据',
        sourceLabel: '原始文本',
        resultLabel: '处理结果',
    },
    gift: {
        title: '礼包转换',
        description: '每行输入累充金额，输出对应礼包',
        sourceLabel: '累充金额',
        resultLabel: '对应礼包',
    },
} as const;

const getLines = (value: string) => value.split(/\r?\n/).map((item) => item.trim()).filter(Boolean);

const getGiftForAmount = (value: string) => {
    const amount = Number(value.replace(/,/g, ''));
    if (!Number.isFinite(amount)) return '无效金额';
    return GIFT_TIERS.find((tier) => amount >= tier.minimum)?.label ?? '未达标';
};

const TextJoinerPage: React.FC = () => {
    const [mode, setMode] = useState<ConverterMode>('join');
    const [source, setSource] = useState('');
    const [result, setResult] = useState('');
    const [copied, setCopied] = useState(false);
    const content = MODE_CONTENT[mode];

    const itemCount = useMemo(
        () => getLines(source).length,
        [source],
    );

    const handleConvert = () => {
        const lines = getLines(source);
        setResult(mode === 'join' ? lines.join(',') : lines.map(getGiftForAmount).join('\n'));
        setCopied(false);
    };

    const handleModeChange = (nextMode: ConverterMode) => {
        if (nextMode === mode) return;
        setMode(nextMode);
        setResult('');
        setCopied(false);
    };

    const handleCopy = async () => {
        if (!result) return;

        try {
            await navigator.clipboard.writeText(result);
        } catch {
            const textarea = document.createElement('textarea');
            textarea.value = result;
            textarea.style.position = 'fixed';
            textarea.style.opacity = '0';
            document.body.appendChild(textarea);
            textarea.select();
            document.execCommand('copy');
            document.body.removeChild(textarea);
        }

        setCopied(true);
        window.setTimeout(() => setCopied(false), 1600);
    };

    return (
        <main className={`text-joiner-page mode-${mode}`}>
            <section className="text-joiner-workspace" aria-label="数据处理工具">
                <header className="text-joiner-header">
                    <div>
                        <h1>{content.title}</h1>
                        <p>{content.description}</p>
                    </div>
                    <div className="text-joiner-header-actions">
                        {source && <span className="text-joiner-count">{itemCount} 项</span>}
                        <div className={`text-joiner-mode-switch mode-${mode}`} role="group" aria-label="转换功能">
                            <button type="button" className={mode === 'join' ? 'is-active' : ''} onClick={() => handleModeChange('join')}>逗号</button>
                            <button type="button" className={mode === 'gift' ? 'is-active' : ''} onClick={() => handleModeChange('gift')}>礼包</button>
                            <span className={mode === 'gift' ? 'is-gift' : ''} aria-hidden="true" />
                        </div>
                    </div>
                </header>

                <div className="text-joiner-editors">
                    <label className="text-joiner-editor">
                        <span>{content.sourceLabel}</span>
                        <textarea
                            value={source}
                            onChange={(event) => setSource(event.target.value)}
                            onKeyDown={(event) => {
                                if ((event.metaKey || event.ctrlKey) && event.key === 'Enter') {
                                    event.preventDefault();
                                    handleConvert();
                                }
                            }}
                            spellCheck={false}
                            autoFocus
                        />
                        {source && (
                            <button className="text-joiner-clear" type="button" onClick={() => { setSource(''); setResult(''); }} aria-label="清空文本">
                                <X size={16} strokeWidth={2} />
                            </button>
                        )}
                    </label>

                    <button className="text-joiner-convert" type="button" onClick={handleConvert} disabled={!source.trim()}>
                        <WandSparkles size={18} strokeWidth={2} />
                        转换
                    </button>

                    <section className="text-joiner-editor text-joiner-output" aria-label="转换结果">
                        <div className="text-joiner-output-label">
                            <span>{content.resultLabel}</span>
                            <button type="button" onClick={handleCopy} disabled={!result} aria-label="复制结果">
                                {copied ? <Check size={16} strokeWidth={2.25} /> : <Copy size={16} strokeWidth={2} />}
                                {copied ? '已复制' : '复制'}
                            </button>
                        </div>
                        <output>{result}</output>
                    </section>
                </div>
            </section>
        </main>
    );
};

export default TextJoinerPage;
