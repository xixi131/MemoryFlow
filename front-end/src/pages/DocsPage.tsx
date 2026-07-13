import React, { useEffect, useMemo, useState } from 'react';
import ReactMarkdown from 'react-markdown';
import { useNavigate } from 'react-router-dom';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { ArrowLeft, ArrowRight, ArrowUp, BookText, ExternalLink } from 'lucide-react';
import { BrandMark } from '../components/web/BrandMark';
import {
  getDocSectionById,
  PRODUCT_DOC_OVERVIEW,
  PRODUCT_DOC_SECTIONS,
  slugify,
} from '../content/productDocs';

const DOC_UI = {
  navTitle: '\u6587\u6863\u5bfc\u822a',
  pageTitle: '\u672c\u9875\u76ee\u5f55',
  backHome: '\u8fd4\u56de\u9996\u9875',
  openWorkspace: '\u8fdb\u5165\u5de5\u4f5c\u53f0',
  previous: '\u4e0a\u4e00\u8282',
  next: '\u4e0b\u4e00\u8282',
  noOutline: '\u672c\u8282\u6ca1\u6709\u66f4\u7ec6\u7684\u5c42\u7ea7\u6807\u9898\u3002',
  note: '\u5f53\u524d\u6587\u6863\u8bf4\u660e\u8986\u76d6\u4ea7\u54c1\u5b9a\u4f4d\u3001\u6838\u5fc3\u529f\u80fd\u3001\u5b89\u88c5\u83b7\u53d6\u4e0e\u5e38\u89c1\u95ee\u9898\u3002',
  chapterCount: (count: number) => `\u5171 ${count} \u4e2a\u7ae0\u8282`,
  sectionCount: (current: number, total: number) => `Section ${current}/${total}`,
};

const extractTextContent = (children: React.ReactNode): string => {
  if (typeof children === 'string' || typeof children === 'number') {
    return String(children);
  }

  if (Array.isArray(children)) {
    return children.map((child) => extractTextContent(child)).join(' ');
  }

  if (React.isValidElement(children)) {
    return extractTextContent((children as React.ReactElement<{ children?: React.ReactNode }>).props.children);
  }

  return '';
};

export const DocsPage: React.FC = () => {
  const navigate = useNavigate();
  const reducedMotion = useReducedMotion();
  const [currentDocId, setCurrentDocId] = useState<string>(PRODUCT_DOC_SECTIONS[0]?.id ?? 'section-1');
  const [activeHeadingId, setActiveHeadingId] = useState<string>('');
  const [pendingHeadingId, setPendingHeadingId] = useState<string | null>(null);
  const [showBackToTop, setShowBackToTop] = useState(false);

  const currentSection = getDocSectionById(currentDocId);
  const currentIndex = PRODUCT_DOC_SECTIONS.findIndex((section) => section.id === currentSection.id);
  const previousSection = currentIndex > 0 ? PRODUCT_DOC_SECTIONS[currentIndex - 1] : null;
  const nextSection = currentIndex < PRODUCT_DOC_SECTIONS.length - 1 ? PRODUCT_DOC_SECTIONS[currentIndex + 1] : null;
  const outlineIds = useMemo(() => currentSection.outline.map((item) => item.id), [currentSection.outline]);

  const handleDocChange = (id: string) => {
    setCurrentDocId(id);
    window.scrollTo({ top: 0, behavior: reducedMotion ? 'auto' : 'smooth' });
  };

  const scrollToHeading = (id: string) => {
    const element = document.getElementById(id);
    if (!element) {
      return;
    }

    const top = element.getBoundingClientRect().top + window.scrollY - 112;
    window.scrollTo({ top, behavior: reducedMotion ? 'auto' : 'smooth' });
  };

  const handleOutlineSelect = (sectionId: string, headingId: string) => {
    setActiveHeadingId(headingId);

    if (sectionId !== currentDocId) {
      setPendingHeadingId(headingId);
      setCurrentDocId(sectionId);
      window.scrollTo({ top: 0, behavior: reducedMotion ? 'auto' : 'smooth' });
      return;
    }

    scrollToHeading(headingId);
  };

  const handleBackToTop = () => {
    window.scrollTo({ top: 0, behavior: reducedMotion ? 'auto' : 'smooth' });
  };

  useEffect(() => {
    if (!pendingHeadingId) {
      return;
    }

    const timer = window.setTimeout(() => {
      scrollToHeading(pendingHeadingId);
      setPendingHeadingId(null);
    }, reducedMotion ? 0 : 80);

    return () => window.clearTimeout(timer);
  }, [currentDocId, pendingHeadingId, reducedMotion]);

  useEffect(() => {
    setActiveHeadingId(currentSection.outline[0]?.id ?? '');
  }, [currentSection.id, currentSection.outline]);

  useEffect(() => {
    const updateState = () => {
      setShowBackToTop(window.scrollY > 420);

      if (outlineIds.length === 0) {
        setActiveHeadingId('');
        return;
      }

      let nextActive = outlineIds[0];
      outlineIds.forEach((id) => {
        const element = document.getElementById(id);
        if (!element) {
          return;
        }

        if (element.getBoundingClientRect().top <= 160) {
          nextActive = id;
        }
      });

      setActiveHeadingId(nextActive);
    };

    updateState();
    window.addEventListener('scroll', updateState, { passive: true });
    return () => window.removeEventListener('scroll', updateState);
  }, [outlineIds]);

  useEffect(() => {
    if (!activeHeadingId) {
      return;
    }

    const anchors = document.querySelectorAll<HTMLElement>(`[data-doc-anchor="${activeHeadingId}"]`);
    anchors.forEach((anchor) => {
      anchor.scrollIntoView({ block: 'nearest', behavior: reducedMotion ? 'auto' : 'smooth' });
    });
  }, [activeHeadingId, reducedMotion]);

  return (
    <div className="mf-shell mf-grid min-h-screen overflow-x-hidden">
      <div className="mf-mesh" aria-hidden="true" />

      <header className="fixed inset-x-0 top-0 z-50 px-4 py-4 md:px-6">
        <div className="mf-glass mx-auto flex max-w-[1600px] items-center justify-between rounded-2xl px-4 py-3 md:px-6">
          <BrandMark subtitle="Product Docs" />
          <div className="flex items-center gap-2 md:gap-3">
            <button
              type="button"
              onClick={() => navigate('/')}
              className="hidden rounded-full px-4 py-2 text-sm font-semibold text-slate-300 transition-colors hover:bg-white/10 hover:text-white md:inline-flex"
            >
              {DOC_UI.backHome}
            </button>
            <button
              type="button"
              onClick={() => navigate('/home')}
              className="mf-button-primary inline-flex items-center gap-2 rounded-full px-4 py-2 text-sm font-semibold transition-all md:px-5"
            >
              {DOC_UI.openWorkspace}
              <ArrowRight className="h-4 w-4" />
            </button>
          </div>
        </div>
      </header>

      <div className="hidden lg:block">
        <aside className="fixed bottom-6 left-[max(1rem,calc(50%-800px+1rem))] top-24 z-30 w-[272px] overflow-hidden rounded-2xl border border-white/10 bg-[rgba(7,11,23,0.55)] backdrop-blur-xl xl:w-[288px]">
          <div className="h-full overflow-y-auto px-4 py-5">
            <div className="px-3 pb-5">
              <p className="text-xs uppercase tracking-[0.24em] text-slate-500">Documentation</p>
              <h2 className="mt-3 text-lg font-semibold text-white">{DOC_UI.navTitle}</h2>
              <p className="mt-2 text-sm leading-6 text-slate-500">{DOC_UI.chapterCount(PRODUCT_DOC_SECTIONS.length)}</p>
            </div>

            <nav className="space-y-1 pb-8">
              {PRODUCT_DOC_SECTIONS.map((section) => {
                const active = currentDocId === section.id;
                return (
                  <div key={section.id} className="px-2 py-1">
                    <button
                      type="button"
                      onClick={() => handleDocChange(section.id)}
                      className={[
                        'w-full rounded-2xl px-3 py-2.5 text-left text-sm font-medium transition-colors',
                        active
                          ? 'bg-cyan-300/10 text-white'
                          : 'text-slate-400 hover:bg-white/5 hover:text-white',
                      ].join(' ')}
                    >
                      {section.rawTitle}
                    </button>

                    {active && section.outline.length > 0 ? (
                      <div className="mt-2 ml-3 border-l border-white/10 pl-3">
                        {section.outline.map((item) => {
                          const outlineActive = activeHeadingId === item.id;
                          return (
                            <button
                              key={item.id}
                              type="button"
                              data-doc-anchor={item.id}
                              onClick={() => handleOutlineSelect(section.id, item.id)}
                              className={[
                                'block w-full rounded-xl px-3 py-2 text-left text-sm leading-6 transition-colors',
                                outlineActive
                                  ? 'bg-white/6 text-cyan-100'
                                  : 'text-slate-500 hover:bg-white/5 hover:text-cyan-100',
                              ].join(' ')}
                            >
                              {item.title}
                            </button>
                          );
                        })}
                      </div>
                    ) : null}
                  </div>
                );
              })}
            </nav>
          </div>
        </aside>
      </div>


      <main className="relative z-10 mx-auto w-full max-w-[1600px] px-4 pb-20 pt-24 md:px-6 lg:pl-[316px] xl:pl-[324px] 2xl:pl-[336px]">
        <section className="mx-auto max-w-4xl min-w-0">
          <div className="overflow-x-auto border-b border-white/8 pb-4 lg:hidden">
            <div className="flex min-w-max gap-2">
              {PRODUCT_DOC_SECTIONS.map((section) => (
                <button
                  key={section.id}
                  type="button"
                  onClick={() => handleDocChange(section.id)}
                  className={[
                    'rounded-full border px-4 py-2 text-sm font-medium transition-colors',
                    currentDocId === section.id
                      ? 'border-cyan-300/20 bg-cyan-300/10 text-cyan-100'
                      : 'border-white/10 bg-white/5 text-slate-300 hover:bg-white/10 hover:text-white',
                  ].join(' ')}
                >
                  {section.rawTitle}
                </button>
              ))}
            </div>
          </div>

          <div className="border-b border-white/8 pb-8 pt-2 lg:pt-4">
            <div className="inline-flex items-center gap-2 rounded-full border border-cyan-300/20 bg-cyan-300/10 px-3 py-1 text-xs font-semibold uppercase tracking-[0.22em] text-cyan-100">
              <BookText className="h-3.5 w-3.5" />
              {DOC_UI.sectionCount(currentIndex + 1, PRODUCT_DOC_SECTIONS.length)}
            </div>
            <h1 className="mt-5 text-4xl font-semibold tracking-[-0.07em] text-white md:text-5xl">{currentSection.rawTitle}</h1>
            <p className="mt-4 max-w-3xl text-base leading-8 text-slate-300">{currentSection.summary}</p>
            <div className="mt-6 rounded-xl border border-white/8 bg-white/[0.03] px-5 py-4 text-sm leading-7 text-slate-400">
              {DOC_UI.note}
            </div>
          </div>

          <AnimatePresence mode="wait">
            <motion.article
              key={currentSection.id}
              initial={reducedMotion ? { opacity: 1 } : { opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              exit={reducedMotion ? { opacity: 1 } : { opacity: 0, y: -12 }}
              transition={{ duration: 0.28, ease: [0.22, 1, 0.36, 1] }}
              className="mf-doc-prose max-w-none py-8"
            >
              <ReactMarkdown
                components={{
                  h1: ({ children, ...props }) => {
                    const id = slugify(extractTextContent(children));
                    return (
                      <h1 id={id} {...props}>
                        {children}
                      </h1>
                    );
                  },
                  h2: ({ children, ...props }) => {
                    const id = slugify(extractTextContent(children));
                    return (
                      <h2 id={id} {...props}>
                        {children}
                      </h2>
                    );
                  },
                  h3: ({ children, ...props }) => {
                    const id = slugify(extractTextContent(children));
                    return (
                      <h3 id={id} {...props}>
                        {children}
                      </h3>
                    );
                  },
                  img: ({ alt, ...props }) => (
                    <figure>
                      <img {...props} alt={alt ?? ''} loading="lazy" decoding="async" />
                      {alt ? <figcaption>{alt}</figcaption> : null}
                    </figure>
                  ),
                  a: ({ href, children, ...props }) => {
                    const external = typeof href === 'string' && /^https?:\/\//.test(href);
                    return (
                      <a
                        href={href}
                        {...props}
                        target={external ? '_blank' : undefined}
                        rel={external ? 'noopener noreferrer' : undefined}
                        className="inline-flex items-center gap-1"
                      >
                        {children}
                        {external ? <ExternalLink className="h-3.5 w-3.5" /> : null}
                      </a>
                    );
                  },
                }}
              >
                {currentSection.content}
              </ReactMarkdown>
            </motion.article>
          </AnimatePresence>

          <div className="mt-4 grid gap-4 border-t border-white/8 pt-8 md:grid-cols-2">
            {previousSection ? (
              <button
                type="button"
                onClick={() => handleDocChange(previousSection.id)}
                className="rounded-xl border border-white/8 bg-white/[0.03] p-5 text-left transition-colors hover:bg-white/[0.05]"
              >
                <span className="inline-flex items-center gap-2 text-sm font-medium text-slate-400">
                  <ArrowLeft className="h-4 w-4" />
                  {DOC_UI.previous}
                </span>
                <span className="mt-3 block text-lg font-semibold text-white">{previousSection.rawTitle}</span>
              </button>
            ) : (
              <div className="hidden md:block" />
            )}

            {nextSection ? (
              <button
                type="button"
                onClick={() => handleDocChange(nextSection.id)}
                className="rounded-[24px] border border-white/8 bg-white/[0.03] p-5 text-left transition-colors hover:bg-white/[0.05] md:text-right"
              >
                <span className="inline-flex items-center gap-2 text-sm font-medium text-slate-400 md:ml-auto">
                  {DOC_UI.next}
                  <ArrowRight className="h-4 w-4" />
                </span>
                <span className="mt-3 block text-lg font-semibold text-white">{nextSection.rawTitle}</span>
              </button>
            ) : null}
          </div>
        </section>
      </main>

      <motion.button
        type="button"
        onClick={handleBackToTop}
        initial={false}
        animate={{ opacity: showBackToTop ? 1 : 0, y: showBackToTop ? 0 : 14 }}
        transition={{ duration: 0.2, ease: [0.22, 1, 0.36, 1] }}
        className="mf-glass fixed bottom-6 right-6 z-40 inline-flex h-12 w-12 items-center justify-center rounded-full text-slate-200 transition-colors hover:text-white"
        style={{ pointerEvents: showBackToTop ? 'auto' : 'none' }}
        aria-label="Back to top"
      >
        <ArrowUp className="h-5 w-5" />
      </motion.button>
    </div>
  );
};

export default DocsPage;