import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  motion,
  useReducedMotion,
  useScroll,
  useSpring,
  useTransform,
} from 'framer-motion';
import {
  ArrowRight,
  BookText,
  BrainCircuit,
  Languages,
  LayoutPanelTop,
  Orbit,
  ShieldCheck,
  Sparkles,
  Workflow,
} from 'lucide-react';
import { BrandMark } from '../components/web/BrandMark';
import { Reveal } from '../components/web/Reveal';
import { HOME_CONTENT, HomeLocale } from '../content/homeContent';

const statIcons = [BrainCircuit, Workflow, Orbit];
const philosophyIcons = [Sparkles, Orbit, BrainCircuit];
const featureIcons = [LayoutPanelTop, Orbit, BrainCircuit, Languages, Sparkles, ShieldCheck];

const HERO_QUOTES: Record<'zh' | 'en', string[]> = {
  zh: [
    '记忆不是才能，而是系统。',
    '复习的成本，远低于重新学习。',
    '知识的半衰期，由你的复习节奏决定。',
    '结构化，是从输入到长期记忆的最短路径。',
    '不需要记住一切，只需要在对的时刻想起它。',
    '艾宾浩斯不需要意志力，只需要时间节点。',
  ],
  en: [
    'Memory is a system, not a talent.',
    'The cost of review is far less than relearning.',
    'Knowledge without revisiting is knowledge on a timer.',
    'Structure is the shortest path from input to recall.',
    "You don't need to remember everything — just schedule it.",
    'The right moment to review is just before you forget.',
  ],
};

const TypewriterQuote: React.FC<{ lang: 'zh' | 'en' }> = ({ lang }) => {
  const quotes = HERO_QUOTES[lang];
  const [quote] = useState(() => quotes[Math.floor(Math.random() * quotes.length)]);
  const [displayed, setDisplayed] = useState('');
  const [done, setDone] = useState(false);

  useEffect(() => {
    setDisplayed('');
    setDone(false);
    let i = 0;
    const timer = setInterval(() => {
      i += 1;
      setDisplayed(quote.slice(0, i));
      if (i >= quote.length) {
        clearInterval(timer);
        setDone(true);
      }
    }, 55);
    return () => clearInterval(timer);
  }, [quote]);

  return (
    <>
      {displayed}
      {!done && (
        <span className="ml-px inline-block h-[0.85em] w-px animate-pulse align-middle bg-current opacity-60" />
      )}
    </>
  );
};

const HomePage: React.FC = () => {
  const navigate = useNavigate();
  const reducedMotion = useReducedMotion();
  const [lang, setLang] = useState<HomeLocale>('zh');
  const content = HOME_CONTENT[lang];
  const { scrollY } = useScroll();
  const heroTracking = lang === 'zh' ? 'tracking-[-0.08em]' : 'tracking-tight';
  const headingTracking = lang === 'zh' ? 'tracking-[-0.06em]' : 'tracking-normal';
  const headingWordSpacing = lang === 'en' ? '[word-spacing:0.18em]' : '';
  const heroYOffset = useSpring(useTransform(scrollY, [0, 400], [0, 72]), {
    stiffness: 120,
    damping: 20,
    mass: 0.8,
  });

  const statNotes =
    lang === 'zh'
      ? [
          ['动态半衰期', '最佳回访窗口'],
          ['章节 / 知识点', '结构化拆解'],
          ['桌面 / Web', '统一节奏'],
        ]
      : [
          ['Dynamic decay', 'Recall window'],
          ['Chapters / points', 'Structured parsing'],
          ['Desktop / Web', 'Unified rhythm'],
        ];

  return (
    <div className="mf-shell mf-grid min-h-screen overflow-x-hidden">
      <div className="mf-mesh" aria-hidden="true" />

      <header className="fixed inset-x-0 top-0 z-50 px-4 py-4 md:px-6">
        <div className="mf-glass mx-auto flex max-w-5xl items-center justify-between rounded-2xl px-4 py-3 md:px-6">
          <BrandMark subtitle="Web Experience" />
          <div className="flex items-center gap-2 md:gap-3">
            <button
              type="button"
              onClick={() => navigate('/docs')}
              className="hidden rounded-full border border-white/10 px-4 py-2 text-sm font-semibold text-slate-200 transition-colors hover:bg-white/10 hover:text-white md:inline-flex"
            >
              {content.nav.docs}
            </button>
            <button
              type="button"
              onClick={() => setLang((current) => (current === 'zh' ? 'en' : 'zh'))}
              className="rounded-full border border-white/10 px-3 py-2 text-sm font-semibold text-slate-200 transition-colors hover:bg-white/10 hover:text-white"
              aria-label="Toggle language"
            >
              {content.nav.languageLabel}
            </button>
            <button
              type="button"
              onClick={() => navigate('/login')}
              className="hidden rounded-full px-4 py-2 text-sm font-semibold text-slate-300 transition-colors hover:text-white md:inline-flex"
            >
              {content.nav.signIn}
            </button>
            <button
              type="button"
              onClick={() => navigate('/home')}
              className="mf-button-primary inline-flex items-center gap-2 whitespace-nowrap rounded-full px-4 py-2 text-sm font-semibold transition-all md:px-5"
            >
              {content.nav.openApp}
              <ArrowRight className="h-4 w-4" />
            </button>
          </div>
        </div>
      </header>

      <main className="relative z-10 pb-24 pt-28 md:pt-32">
        {/* Hero — centered layout */}
        <section className="mx-auto flex min-h-[calc(100vh-10rem)] max-w-4xl flex-col items-center justify-center px-4 text-center md:px-6">
          <motion.div
            style={reducedMotion ? undefined : { y: heroYOffset }}
            className="flex flex-col items-center gap-6"
          >
            <motion.div
              initial={reducedMotion ? false : { opacity: 0, y: 24 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.78, ease: [0.22, 1, 0.36, 1] }}
            >
              <span className="mf-kicker">{content.hero.badge}</span>
            </motion.div>
            <motion.div
              initial={reducedMotion ? false : { opacity: 0, y: 24 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.78, delay: 0.05, ease: [0.22, 1, 0.36, 1] }}
            >
              <div className="space-y-5">
                <h1 className={`mf-hero-title text-5xl font-semibold ${heroTracking} text-white sm:text-6xl lg:text-7xl`}>
                  <span className="block">{content.hero.title[0]}</span>
                  <span className="mf-gradient-text block pb-2">{content.hero.title[1]}</span>
                  <span className="block text-slate-300">{content.hero.title[2]}</span>
                </h1>
                <p className="mx-auto max-w-2xl text-base leading-8 text-slate-300 sm:text-lg">
                  {content.hero.subtitle}
                </p>
              </div>
            </motion.div>
            <motion.div
              initial={reducedMotion ? false : { opacity: 0, y: 24 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.78, delay: 0.1, ease: [0.22, 1, 0.36, 1] }}
            >
              <div className="flex flex-col items-center gap-3 sm:flex-row">
                <button
                  type="button"
                  onClick={() => navigate('/home')}
                  className="mf-button-primary inline-flex items-center justify-center gap-2 rounded-full px-6 py-3 text-sm font-semibold transition-all"
                >
                  {content.hero.primaryCta}
                  <ArrowRight className="h-4 w-4" />
                </button>
                <button
                  type="button"
                  onClick={() => navigate('/docs')}
                  className="mf-button-secondary inline-flex items-center justify-center gap-2 rounded-full px-6 py-3 text-sm font-semibold transition-all"
                >
                  <BookText className="h-4 w-4" />
                  {content.hero.secondaryCta}
                </button>
              </div>
            </motion.div>
            <motion.div
              initial={reducedMotion ? false : { opacity: 0, y: 24 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.78, delay: 0.15, ease: [0.22, 1, 0.36, 1] }}
            >
              <div className="flex h-6 items-center justify-center overflow-hidden">
                <p className="text-sm text-slate-500">
                  <TypewriterQuote key={lang} lang={lang} />
                </p>
              </div>
            </motion.div>
          </motion.div>
        </section>

        {/* Stats — horizontal metrics bar */}
        <section className="mx-auto max-w-5xl px-4 md:px-6">
          <div className="grid gap-4 md:grid-cols-3">
            {content.stats.map((stat, index) => {
              const Icon = statIcons[index] ?? Sparkles;
              return (
                <Reveal key={stat.label} delay={0.2 + index * 0.05}>
                  <div className="mf-glass h-full rounded-2xl p-5">
                    <div className="flex items-start gap-4">
                      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-cyan-300/10 bg-cyan-300/10 text-cyan-200">
                        <Icon className="h-5 w-5" />
                      </div>
                      <div className="min-w-0">
                        <div className="text-xl font-semibold text-white">{stat.value}</div>
                        <div className="mt-1 text-sm font-medium text-slate-300">{stat.label}</div>
                      </div>
                    </div>
                    <p className="mt-3 text-sm leading-6 text-slate-500">{stat.detail}</p>
                    <div className="mt-3 flex flex-wrap gap-1.5">
                      {statNotes[index].map((note) => (
                        <span
                          key={note}
                          className="rounded-full border border-white/8 bg-white/5 px-2.5 py-0.5 text-[11px] font-medium text-slate-400"
                        >
                          {note}
                        </span>
                      ))}
                    </div>
                  </div>
                </Reveal>
              );
            })}
          </div>
        </section>

        {/* Showcase */}
        <section className="mx-auto mt-24 max-w-5xl px-4 md:px-6">
          <Reveal>
            <div className="rounded-2xl border border-white/10 bg-white/[0.02] p-6 lg:p-8">
              <div className="mb-8 max-w-2xl space-y-4">
                <span className="mf-kicker">{content.showcase.eyebrow}</span>
                <h2 className={`text-3xl font-semibold ${headingTracking} ${headingWordSpacing} text-white md:text-4xl`}>
                  {content.showcase.title}
                </h2>
                <p className="text-base leading-8 text-slate-300">{content.showcase.description}</p>
              </div>
              <div className="grid gap-4 md:grid-cols-3">
                {content.showcase.panels.map((panel) => (
                  <div key={panel.tag} className="mf-glass rounded-2xl p-5">
                    <div className="text-xs uppercase tracking-[0.24em] text-cyan-200">{panel.tag}</div>
                    <h3 className="mt-3 text-lg font-semibold text-white">{panel.title}</h3>
                    <p className="mt-2 text-sm leading-7 text-slate-400">{panel.description}</p>
                  </div>
                ))}
              </div>
            </div>
          </Reveal>
        </section>

        {/* Philosophy */}
        <section className="mx-auto mt-24 max-w-5xl px-4 md:px-6">
          <Reveal>
            <div className="mb-10 max-w-3xl space-y-4">
              <span className="mf-kicker">{content.philosophy.eyebrow}</span>
              <h2 className="text-3xl font-semibold tracking-[-0.06em] text-white md:text-4xl">
                {content.philosophy.title}
              </h2>
              <p className="text-base leading-8 text-slate-300">{content.philosophy.description}</p>
            </div>
          </Reveal>
          <div className="grid gap-4 md:grid-cols-3">
            {content.philosophy.items.map((item, index) => {
              const Icon = philosophyIcons[index] ?? Sparkles;
              return (
                <Reveal key={item.title} delay={index * 0.06}>
                  <div className="mf-glass h-full rounded-2xl p-6">
                    <div className="mb-5 inline-flex h-10 w-10 items-center justify-center rounded-xl border border-white/10 bg-white/5 text-cyan-200">
                      <Icon className="h-5 w-5" />
                    </div>
                    <h3 className="text-xl font-semibold text-white">{item.title}</h3>
                    <p className="mt-3 text-sm leading-7 text-slate-400">{item.description}</p>
                  </div>
                </Reveal>
              );
            })}
          </div>
        </section>

        {/* Workflow */}
        <section className="mx-auto mt-24 max-w-5xl px-4 md:px-6">
          <Reveal>
            <div className="mb-10 max-w-3xl space-y-4">
              <span className="mf-kicker">{content.workflow.eyebrow}</span>
              <h2 className="text-3xl font-semibold tracking-[-0.06em] text-white md:text-4xl">
                {content.workflow.title}
              </h2>
              <p className="text-base leading-8 text-slate-300">{content.workflow.description}</p>
            </div>
          </Reveal>
          <div className="grid gap-4 lg:grid-cols-4">
            {content.workflow.items.map((item, index) => (
              <Reveal key={item.title} delay={index * 0.05}>
                <div className="mf-panel relative h-full rounded-2xl p-6">
                  <div className="mb-5 flex h-10 w-10 items-center justify-center rounded-full border border-cyan-300/20 bg-cyan-300/10 text-sm font-semibold text-cyan-100">
                    0{index + 1}
                  </div>
                  <h3 className="text-lg font-semibold text-white">{item.title}</h3>
                  <p className="mt-3 text-sm leading-7 text-slate-400">{item.description}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </section>

        {/* Features */}
        <section className="mx-auto mt-24 max-w-5xl px-4 md:px-6">
          <Reveal>
            <div className="mb-10 max-w-3xl space-y-4">
              <span className="mf-kicker">{content.features.eyebrow}</span>
              <h2 className="text-3xl font-semibold tracking-[-0.06em] text-white md:text-4xl">
                {content.features.title}
              </h2>
              <p className="text-base leading-8 text-slate-300">{content.features.description}</p>
            </div>
          </Reveal>
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {content.features.items.map((item, index) => {
              const Icon = featureIcons[index] ?? Sparkles;
              return (
                <Reveal key={item.title} delay={index * 0.04}>
                  <div className="mf-glass group h-full rounded-2xl p-6 transition-transform duration-300 hover:-translate-y-1">
                    <div className="mb-4 inline-flex rounded-full border border-white/10 bg-white/5 px-3 py-1 text-xs uppercase tracking-[0.22em] text-cyan-100">
                      {item.eyebrow}
                    </div>
                    <div className="mb-5 flex h-10 w-10 items-center justify-center rounded-xl border border-white/10 bg-white/5 text-cyan-200 transition-colors group-hover:border-cyan-300/20 group-hover:bg-cyan-300/10">
                      <Icon className="h-5 w-5" />
                    </div>
                    <h3 className="text-xl font-semibold text-white">{item.title}</h3>
                    <p className="mt-3 text-sm leading-7 text-slate-400">{item.description}</p>
                  </div>
                </Reveal>
              );
            })}
          </div>
        </section>

        {/* Closing CTA */}
        <section className="mx-auto mt-24 max-w-5xl px-4 md:px-6">
          <Reveal>
            <div className="mf-glass overflow-hidden rounded-2xl p-8 md:p-10">
              <div className="grid gap-10 lg:grid-cols-[minmax(0,1.05fr)_auto] lg:items-end">
                <div className="space-y-5">
                  <span className="mf-kicker">MemoryFlow</span>
                  <h2 className={`max-w-3xl text-3xl font-semibold ${headingTracking} ${headingWordSpacing} text-white md:text-5xl`}>
                    {content.closing.title}
                  </h2>
                  <p className="max-w-2xl text-base leading-8 text-slate-300">{content.closing.description}</p>
                </div>
                <div className="flex flex-col gap-3 sm:flex-row lg:flex-col">
                  <button
                    type="button"
                    onClick={() => navigate('/home')}
                    className="mf-button-primary inline-flex items-center justify-center gap-2 rounded-full px-6 py-3 text-sm font-semibold transition-all"
                  >
                    {content.closing.primaryCta}
                    <ArrowRight className="h-4 w-4" />
                  </button>
                  <button
                    type="button"
                    onClick={() => navigate('/docs')}
                    className="mf-button-secondary inline-flex items-center justify-center gap-2 rounded-full px-6 py-3 text-sm font-semibold transition-all"
                  >
                    <BookText className="h-4 w-4" />
                    {content.closing.secondaryCta}
                  </button>
                </div>
              </div>
            </div>
          </Reveal>
        </section>
      </main>
    </div>
  );
};

export default HomePage;
