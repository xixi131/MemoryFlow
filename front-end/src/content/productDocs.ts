import productDocMarkdown from '../../docs/MemoryFlow 产品文档.md?raw';

export interface DocOutlineItem {
  id: string;
  title: string;
  level: 2 | 3;
}

export interface DocSection {
  id: string;
  order: number;
  rawTitle: string;
  title: string;
  summary: string;
  content: string;
  outline: DocOutlineItem[];
}

const FAQ_APPENDIX = `
## 4. 常见问题 (FAQ)

**Q: 为什么我无法注册？**

A: 当前仅开放邀请注册，请联系管理员获取邀请链接。

**Q: 是否支持 Mac 或 Linux？**

A: 当前仅支持 Windows 平台，Mac 和 Linux 版本仍在规划中。

**Q: 数据是否会同步？**

A: 会。现有学习数据会同步到云端，网页端和桌面端保持一致的数据结果。
`;

const DOC_ASSET_REPLACEMENTS: Array<[RegExp, string]> = [
  [
    /!\[b3859f79a70b404b8abc7b443c64521d\]\([^)]+\)/g,
    '![灵动岛应用模式截图](/灵动岛应用模式图片.png)',
  ],
  [
    /!\[dbffea13432d33fd41c2d1b890fd1be4\]\([^)]+\)/g,
    '![灵动岛音乐模式截图](/灵动岛音乐模式图片.png)',
  ],
  [/\((?:[A-Z]:)?[^)\n]*灵动岛应用模式动画\.gif\)/g, '(/灵动岛应用模式动画.gif)'],
  [/\((?:[A-Z]:)?[^)\n]*灵动岛音乐模式动画\.gif\)/g, '(/灵动岛音乐模式动画.gif)'],
  [/\((?:[A-Z]:)?[^)\n]*灵动岛音乐模式音乐控制动画\.gif\)/g, '(/灵动岛音乐模式音乐控制动画.gif)'],
  [/\((?:[A-Z]:)?[^)\n]*AI 驱动的知识架构动画\.gif\)/g, '(/AI 驱动的知识架构动画.gif)'],
  [/\((?:[A-Z]:)?[^)\n]*英语模块背单词动画\.gif\)/g, '(/英语模块背单词动画.gif)'],
  [/\((?:[A-Z]:)?[^)\n]*英语模块日历回溯动画\.gif\)/g, '(/英语模块日历回溯动画.gif)'],
];

export const slugify = (value: string) =>
  value
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s-]/gu, '')
    .replace(/\s+/g, '-');

const stripMarkdown = (value: string) =>
  value
    .replace(/!\[[^\]]*\]\([^)]+\)/g, ' ')
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
    .replace(/`([^`]+)`/g, '$1')
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/\*([^*]+)\*/g, '$1')
    .replace(/^#+\s+/gm, '')
    .replace(/^>\s?/gm, '')
    .replace(/^\s*[-*+]\s+/gm, '')
    .replace(/^\s*\d+\.\s+/gm, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\r?\n+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

const normalizeMarkdown = (markdown: string) => {
  let normalized = markdown.replace(/\r\n/g, '\n').trim();

  DOC_ASSET_REPLACEMENTS.forEach(([pattern, replacement]) => {
    normalized = normalized.replace(pattern, replacement);
  });

  normalized = normalized.split('**© 2024 MemoryFlow Team.**')[0].trim();
  normalized = normalized.replace(/\n{3,}/g, '\n\n');

  return `${normalized}\n\n---\n\n${FAQ_APPENDIX.trim()}`;
};

const extractSummary = (content: string) => {
  const body = content.replace(/^##\s+.+$/m, '').trim();
  const blocks = body
    .split(/\n{2,}/)
    .map((block) => stripMarkdown(block))
    .filter(Boolean);

  return blocks[0] ?? '';
};

const parseSections = (markdown: string): DocSection[] => {
  const matches = Array.from(markdown.matchAll(/^##\s+(.+)$/gm));

  return matches.map((match, index) => {
    const start = match.index ?? 0;
    const end = index + 1 < matches.length ? matches[index + 1].index ?? markdown.length : markdown.length;
    const rawContent = markdown.slice(start, end).trim();
    const rawTitle = match[1].trim();
    const sectionNumber = Number(rawTitle.match(/^(\d+)/)?.[1] ?? index + 1);
    const title = stripMarkdown(rawTitle.replace(/^\d+\.\s*/, '').trim());
    const outline = Array.from(rawContent.matchAll(/^###\s+(.+)$/gm)).map((headingMatch) => {
      const headingTitle = stripMarkdown(headingMatch[1].trim());
      return {
        id: slugify(headingTitle),
        title: headingTitle,
        level: 3 as const,
      };
    });

    return {
      id: `section-${sectionNumber}`,
      order: sectionNumber,
      rawTitle: stripMarkdown(rawTitle),
      title,
      summary: extractSummary(rawContent),
      content: rawContent,
      outline,
    };
  });
};

const normalizedDocs = normalizeMarkdown(productDocMarkdown);

export const PRODUCT_DOC_SECTIONS = parseSections(normalizedDocs);

export const PRODUCT_DOC_OVERVIEW = {
  title: 'MemoryFlow 产品文档',
  description:
    '围绕无感复习、AI 知识结构化与桌面灵动岛体验构建的产品说明，包含页面结构、功能机制、获取方式与兼容性边界。',
  note: '当前文档说明覆盖产品定位、核心功能、安装获取与常见问题。',
};

export const getDocSectionById = (id: string) =>
  PRODUCT_DOC_SECTIONS.find((section) => section.id === id) ?? PRODUCT_DOC_SECTIONS[0];