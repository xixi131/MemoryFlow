export type HomeLocale = 'zh' | 'en';

type FeatureItem = {
  title: string;
  description: string;
  eyebrow: string;
};

type PhilosophyItem = {
  title: string;
  description: string;
};

type WorkflowItem = {
  title: string;
  description: string;
};

type StatItem = {
  value: string;
  label: string;
  detail: string;
};

type ExperiencePanel = {
  title: string;
  description: string;
  tag: string;
};

type LocaleContent = {
  nav: {
    docs: string;
    signIn: string;
    openApp: string;
    languageLabel: string;
  };
  hero: {
    badge: string;
    title: [string, string, string];
    subtitle: string;
    primaryCta: string;
    secondaryCta: string;
    tertiaryNote: string;
  };
  stats: StatItem[];
  showcase: {
    eyebrow: string;
    title: string;
    description: string;
    panels: ExperiencePanel[];
    previewLabels: {
      workspace: string;
      review: string;
      ai: string;
      dynamicIsland: string;
      retention: string;
      today: string;
      smartQueue: string;
      structuredImport: string;
    };
  };
  philosophy: {
    eyebrow: string;
    title: string;
    description: string;
    items: PhilosophyItem[];
  };
  workflow: {
    eyebrow: string;
    title: string;
    description: string;
    items: WorkflowItem[];
  };
  features: {
    eyebrow: string;
    title: string;
    description: string;
    items: FeatureItem[];
  };
  closing: {
    title: string;
    description: string;
    primaryCta: string;
    secondaryCta: string;
  };
};

export const HOME_CONTENT: Record<HomeLocale, LocaleContent> = {
  zh: {
    nav: {
      docs: '产品文档',
      signIn: '登录',
      openApp: '进入工作台',
      languageLabel: 'EN',
    },
    hero: {
      badge: '基于无感复习、AI 结构化与沉浸式交互的记忆系统',
      title: ['让记忆管理', '像系统呼吸一样', '自然发生'],
      subtitle:
        'MemoryFlow 将艾宾浩斯调度、AI 知识架构与桌面灵动岛体验收束到同一个产品闭环，让复习、沉淀和回想不再依赖意志力硬撑。',
      primaryCta: '立即开始',
      secondaryCta: '阅读文档',
      tertiaryNote: '仅重构 Web 端表现层，保留现有业务逻辑、权限与接口行为。',
    },
    stats: [
      {
        value: 'Ebbinghaus+',
        label: '复习调度',
        detail: '按知识点动态计算最佳回访窗口',
      },
      {
        value: 'AI Parsing',
        label: '内容结构化',
        detail: '将非结构化输入拆解为章节与知识点',
      },
      {
        value: '24/7',
        label: '统一体验',
        detail: '桌面灵动岛、Web 与学习流程保持一致',
      },
    ],
    showcase: {
      eyebrow: '核心体验',
      title: '三大场景，一套完整的记忆闭环',
      description:
        'MemoryFlow 围绕桌面灵动岛、AI 知识架构与语言记忆引擎三大核心场景，将碎片化的学习动作收束成一条连贯的记忆链路。',
      panels: [
        {
          tag: '桌面灵动岛',
          title: '无感复习入口',
          description: '待复习与已完成状态被折叠进常驻入口，减少启动负担。',
        },
        {
          tag: 'AI Knowledge',
          title: '结构化知识架构',
          description: '从原始资料到章节拆解与进度规划，保持同一套信息模型。',
        },
        {
          tag: 'Language Mastery',
          title: '语言学习记忆引擎',
          description: '词库、日历回溯、动态调度形成长期记忆闭环。',
        },
      ],
      previewLabels: {
        workspace: '学习工作台',
        review: '今日复习',
        ai: 'AI 结构化',
        dynamicIsland: '桌面灵动岛',
        retention: '记忆留存',
        today: '今日完成',
        smartQueue: '智能队列',
        structuredImport: '结构化导入',
      },
    },
    philosophy: {
      eyebrow: '设计理念',
      title: '三个不能动的产品底层原则',
      description:
        '这次重构只升级表现层，不改产品规则。设计和代码组织都围绕原文档中的产品哲学重新表达，而不是重新定义业务。',
      items: [
        {
          title: '无感复习',
          description: '把提醒、回顾与下一次动作嵌入低负担入口，减少启动门槛。',
        },
        {
          title: '统一体验',
          description: '学习、回顾、娱乐控制与资料管理使用同一套视觉和信息节奏。',
        },
        {
          title: '数据驱动',
          description: '调度、状态展示与学习路径表达都围绕算法结果而不是手工编排。',
        },
      ],
    },
    workflow: {
      eyebrow: '产品流程',
      title: '从输入资料到形成长期记忆的闭环',
      description:
        '页面结构围绕用户真实任务推进：导入资料、结构化、安排复习、查看轨迹、再次强化。',
      items: [
        {
          title: '输入资料',
          description: '用户提供原始知识、词汇或笔记内容，系统负责接管后续编排。',
        },
        {
          title: 'AI 结构化',
          description: '通过 JSON Schema 提示与语法树解析将内容整理成章节和知识点。',
        },
        {
          title: '智能调度',
          description: '基于改进版艾宾浩斯曲线生成复习窗口与当日队列。',
        },
        {
          title: '持续回访',
          description: '通过 Web、日历和桌面入口完成查看、回顾和再次强化。',
        },
      ],
    },
    features: {
      eyebrow: '核心能力',
      title: '首页需要准确传达的产品价值',
      description:
        '所有内容都直接来自产品文档：不是泛泛而谈的 SaaS 宣传，而是清晰解释 MemoryFlow 为什么不同。',
      items: [
        {
          eyebrow: 'Desktop Dynamic Island',
          title: '双模式灵动岛入口',
          description: '在应用模式和音乐模式之间自然切换，同时承载复习概览与媒体控制。',
        },
        {
          eyebrow: 'Immersive Music Control',
          title: '沉浸式媒体接管',
          description: '利用 SMTC 获取元数据、进度与专辑视觉，强化系统级沉浸体验。',
        },
        {
          eyebrow: 'AI-Powered Knowledge Architecture',
          title: '知识结构自动成形',
          description: '把非结构化输入转为学习路径，而不只是生成一段内容。',
        },
        {
          eyebrow: 'Language Mastery Engine',
          title: '词汇记忆引擎',
          description: '词库、发音、例句、日历回溯和记忆半衰期共同形成语言学习闭环。',
        },
        {
          eyebrow: 'UI Engineering',
          title: 'Squircle 与流体动效',
          description: '精细边角、层叠玻璃与克制过渡共同构成成熟而可信的产品质感。',
        },
        {
          eyebrow: 'Invite-only Access',
          title: '邀请制访问与安全验证',
          description: '注册、权限与客户端下载链路保持现有规则与结果不变。',
        },
      ],
    },
    closing: {
      title: '把注意力留给学习，把安排交给系统',
      description:
        '进入工作台继续现有业务流程，或者先阅读产品文档了解页面结构、功能说明与交互边界。',
      primaryCta: '进入工作台',
      secondaryCta: '查看文档',
    },
  },
  en: {
    nav: {
      docs: 'Docs',
      signIn: 'Sign In',
      openApp: 'Open Workspace',
      languageLabel: '中',
    },
    hero: {
      badge: 'A memory system built on frictionless review, AI structuring, and immersive interaction',
      title: ['Make memory work', 'feel like a system', 'instead of effort'],
      subtitle:
        'MemoryFlow brings Ebbinghaus scheduling, AI knowledge architecture, and the Dynamic Island desktop experience into one closed-loop product so review becomes consistent instead of exhausting.',
      primaryCta: 'Get Started',
      secondaryCta: 'Read Docs',
      tertiaryNote: 'Web visuals are upgraded without changing existing business logic, permissions, or API behavior.',
    },
    stats: [
      {
        value: 'Ebbinghaus+',
        label: 'Review Scheduling',
        detail: 'Each knowledge point gets its own revisit window',
      },
      {
        value: 'AI Parsing',
        label: 'Structured Content',
        detail: 'Unstructured input becomes chapters and key points',
      },
      {
        value: '24/7',
        label: 'Unified Experience',
        detail: 'Desktop, Web, and learning workflows stay aligned',
      },
    ],
    showcase: {
      eyebrow: 'Core Experience',
      title: 'Three scenarios, one complete memory loop',
      description:
        'MemoryFlow weaves the Desktop Dynamic Island, AI Knowledge Architecture, and Language Mastery Engine into a single coherent memory pipeline that turns scattered study actions into lasting recall.',
      panels: [
        {
          tag: 'Dynamic Island',
          title: 'Frictionless review entry',
          description: 'Pending and completed reviews stay condensed in a low-friction persistent touchpoint.',
        },
        {
          tag: 'AI Knowledge',
          title: 'Structured knowledge architecture',
          description: 'Raw material, chapter breakdowns, and progress planning all follow one information model.',
        },
        {
          tag: 'Language Mastery',
          title: 'Long-term vocabulary engine',
          description: 'Lexicon, calendar recall, and dynamic scheduling close the loop on language memory.',
        },
      ],
      previewLabels: {
        workspace: 'Learning Workspace',
        review: 'Review Queue',
        ai: 'AI Structuring',
        dynamicIsland: 'Dynamic Island',
        retention: 'Retention',
        today: 'Completed Today',
        smartQueue: 'Smart Queue',
        structuredImport: 'Structured Import',
      },
    },
    philosophy: {
      eyebrow: 'Design philosophy',
      title: 'Three product principles that cannot move',
      description:
        'This refactor upgrades the presentation layer only. The design and component structure are realigned around the documented product philosophy instead of redefining business behavior.',
      items: [
        {
          title: 'Zero-Friction Review',
          description: 'Reminders, review, and the next action stay embedded in a low-friction entry point.',
        },
        {
          title: 'Unified Experience',
          description: 'Learning, review, leisure media control, and material management keep one visual rhythm.',
        },
        {
          title: 'Data-Driven',
          description: 'Scheduling, state display, and learning paths follow algorithmic results rather than manual ordering.',
        },
      ],
    },
    workflow: {
      eyebrow: 'Workflow',
      title: 'A full loop from raw material to long-term recall',
      description:
        'The page structure is built around the actual user task flow: ingest material, structure it, schedule reviews, inspect history, and reinforce again.',
      items: [
        {
          title: 'Ingest material',
          description: 'Users provide notes, knowledge, or vocabulary while the system takes over the structure.',
        },
        {
          title: 'AI structuring',
          description: 'JSON Schema prompting and syntax-tree parsing convert content into chapters and key points.',
        },
        {
          title: 'Intelligent scheduling',
          description: 'Review windows and daily queues are generated from an improved Ebbinghaus model.',
        },
        {
          title: 'Continuous revisit',
          description: 'Web, calendar, and desktop entry points keep recall and reinforcement in motion.',
        },
      ],
    },
    features: {
      eyebrow: 'Capabilities',
      title: 'The product value the homepage must communicate',
      description:
        'Everything here comes directly from the product document. It is not generic SaaS messaging; it explains why MemoryFlow is distinct.',
      items: [
        {
          eyebrow: 'Desktop Dynamic Island',
          title: 'Bi-modal Dynamic Island entry',
          description: 'It switches naturally between app and music modes while carrying review overview and media control.',
        },
        {
          eyebrow: 'Immersive Music Control',
          title: 'System-level media takeover',
          description: 'SMTC powers metadata, progress, and album visuals for a more immersive system experience.',
        },
        {
          eyebrow: 'AI-Powered Knowledge Architecture',
          title: 'Knowledge structures itself',
          description: 'The system produces learning paths, not just a generated block of content.',
        },
        {
          eyebrow: 'Language Mastery Engine',
          title: 'Vocabulary retention engine',
          description: 'Lexicons, pronunciation, examples, calendar recall, and memory decay work as one loop.',
        },
        {
          eyebrow: 'UI Engineering',
          title: 'Squircle and fluid motion',
          description: 'Refined radii, layered glass, and restrained transitions create a credible premium surface.',
        },
        {
          eyebrow: 'Invite-only Access',
          title: 'Invite-only access with verification',
          description: 'Registration, permissions, and download flows keep their existing rules and outcomes.',
        },
      ],
    },
    closing: {
      title: 'Keep attention on learning and let the system handle the schedule',
      description:
        'Open the workspace to continue the current flow, or read the product docs first for structure, features, and interaction boundaries.',
      primaryCta: 'Open Workspace',
      secondaryCta: 'View Docs',
    },
  },
};
