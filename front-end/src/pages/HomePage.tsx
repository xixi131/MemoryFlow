import React, { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, useScroll, useTransform, useSpring, useMotionValue, useMotionTemplate } from 'framer-motion';

// --- Components ---

// --- Translations ---
const translations = {
    en: {
        signIn: "Sign In",
        getStarted: "Get Started",
        capture: "Capture.",
        flow: "Flow.",
        master: "Master.",
        subtitle: "The intelligent knowledge management system that adapts to your mind. Experience the flow state of learning.",
        startJourney: "Start Your Journey",
        retentionRate: "Retention Rate",
        activeGoals: "Active Goals",
        possibilities: "Possibilities",
        whyMemoryFlow: "Why MemoryFlow?",
        engineeredFor: "Engineered for",
        cognitiveExcellence: "Cognitive Excellence",
        footerDesc: "Empowering your learning journey through science and design.",
        product: "Product",
        company: "Company",
        legal: "Legal",
        featuresList: ["Features", "Pricing", "Integrations", "Changelog"],
        companyList: ["About", "Blog", "Careers", "Contact"],
        legalList: ["Privacy", "Terms", "Security"],
        rights: "All rights reserved.",
        features: [
            { 
                title: 'Smart Spacing', 
                desc: 'Our algorithm predicts exactly when you are about to forget, ensuring efficient long-term retention.', 
                icon: 'psychology' 
            },
            { 
                title: 'Visual Analytics', 
                desc: 'Beautiful charts and heatmaps visualize your learning patterns and progress over time.', 
                icon: 'monitoring' 
            },
            { 
                title: 'Goal Tracking', 
                desc: 'Set ambitious goals and break them down into manageable daily chunks.', 
                icon: 'flag' 
            },
            { 
                title: 'Focus Mode', 
                desc: 'A distraction-free environment designed to help you enter the flow state instantly.', 
                icon: 'do_not_disturb_on' 
            },
            { 
                title: 'Knowledge Graph', 
                desc: 'Connect concepts and build a resilient web of knowledge that grows with you.', 
                icon: 'hub' 
            },
            { 
                title: 'Multi-platform', 
                desc: 'Seamlessly sync your progress across all devices. Learn anywhere, anytime.', 
                icon: 'devices' 
            }
        ],
        readyToFind: "Ready to find your",
        flowQuestion: "flow?",
        joinThousands: "Join thousands of learners who have transformed the way they acquire and retain knowledge.",
        getStartedFree: "Get Started for Free"
    },
    zh: {
        signIn: "登录",
        getStarted: "立即开始",
        capture: "捕捉灵感",
        flow: "心流体验",
        master: "掌握知识",
        subtitle: "适应你思维的智能知识管理系统。体验学习的心流状态。",
        startJourney: "开启旅程",
        retentionRate: "记忆留存率",
        activeGoals: "当前目标",
        possibilities: "无限可能",
        whyMemoryFlow: "为什么选择 MemoryFlow？",
        engineeredFor: "专为打造",
        cognitiveExcellence: "卓越认知能力",
        footerDesc: "通过科学与设计赋能你的学习之旅。",
        product: "产品",
        company: "公司",
        legal: "法律",
        featuresList: ["功能", "价格", "集成", "更新日志"],
        companyList: ["关于", "博客", "招聘", "联系"],
        legalList: ["隐私", "条款", "安全"],
        rights: "版权所有。",
        features: [
            { 
                title: '智能间隔', 
                desc: '我们的算法精准预测遗忘时间点，确保高效的长期记忆留存。', 
                icon: 'psychology' 
            },
            { 
                title: '可视化分析', 
                desc: '精美的图表和热力图可视化你的学习模式和随时间变化的进度。', 
                icon: 'monitoring' 
            },
            { 
                title: '目标追踪', 
                desc: '设定宏大目标，并将其分解为可管理的每日任务。', 
                icon: 'flag' 
            },
            { 
                title: '专注模式', 
                desc: '无干扰环境设计，助你瞬间进入心流状态。', 
                icon: 'do_not_disturb_on' 
            },
            { 
                title: '知识图谱', 
                desc: '连接概念，构建随你一同成长的弹性知识网络。', 
                icon: 'hub' 
            },
            { 
                title: '多平台同步', 
                desc: '在所有设备间无缝同步进度。随时随地，想学就学。', 
                icon: 'devices' 
            }
        ],
        readyToFind: "准备好寻找你的",
        flowQuestion: "心流了吗？",
        joinThousands: "加入成千上万的学习者，改变你获取和保留知识的方式。",
        getStartedFree: "免费开始"
    }
};

// 1. 动态液态背景 (Liquid Background)
const LiquidBackground = () => {
    return (
        <div className="fixed inset-0 z-0 overflow-hidden bg-[#faf9f6]">
            {/* 细腻的噪点纹理 */}
            <div className="absolute inset-0 bg-[url('https://grainy-gradients.vercel.app/noise.svg')] opacity-30 mix-blend-multiply pointer-events-none"></div>
            
            {/* 流动的色彩斑点 - 使用暖色调: 橙、粉、黄、青 */}
            <motion.div 
                animate={{ 
                    x: [0, 100, 0], 
                    y: [0, -50, 0],
                    scale: [1, 1.2, 1]
                }}
                transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
                className="absolute top-[-10%] left-[-10%] w-[60vw] h-[60vw] rounded-full bg-gradient-to-r from-orange-300/40 to-amber-200/40 blur-[100px]" 
            />
            <motion.div 
                animate={{ 
                    x: [0, -100, 0], 
                    y: [0, 100, 0],
                    rotate: [0, 180, 360]
                }}
                transition={{ duration: 25, repeat: Infinity, ease: "linear" }}
                className="absolute bottom-[-10%] right-[-10%] w-[50vw] h-[50vw] rounded-full bg-gradient-to-r from-rose-300/30 to-pink-200/30 blur-[120px]" 
            />
            <motion.div 
                animate={{ 
                    scale: [1, 1.5, 1],
                    opacity: [0.3, 0.6, 0.3]
                }}
                transition={{ duration: 15, repeat: Infinity, ease: "easeInOut" }}
                className="absolute top-[30%] left-[30%] w-[40vw] h-[40vw] rounded-full bg-gradient-to-r from-emerald-200/30 to-teal-100/30 blur-[90px]" 
            />
        </div>
    );
};

// 2. 磁吸按钮 (Magnetic Button)
const MagneticButton = ({ children, onClick, className }: { children: React.ReactNode, onClick?: () => void, className?: string }) => {
    const ref = useRef<HTMLButtonElement>(null);
    const x = useMotionValue(0);
    const y = useMotionValue(0);
    const textX = useMotionValue(0);
    const textY = useMotionValue(0);

    const handleMouseMove = (e: React.MouseEvent) => {
        if (!ref.current) return;
        const rect = ref.current.getBoundingClientRect();
        const centerX = rect.left + rect.width / 2;
        const centerY = rect.top + rect.height / 2;
        
        // 按钮本身的移动范围较大
        x.set((e.clientX - centerX) * 0.3);
        y.set((e.clientY - centerY) * 0.3);

        // 文字的移动范围较小，产生视差
        textX.set((e.clientX - centerX) * 0.1);
        textY.set((e.clientY - centerY) * 0.1);
    };

    const handleMouseLeave = () => {
        x.set(0);
        y.set(0);
        textX.set(0);
        textY.set(0);
    };

    return (
        <motion.button
            ref={ref}
            style={{ x, y }}
            onMouseMove={handleMouseMove}
            onMouseLeave={handleMouseLeave}
            onClick={onClick}
            whileTap={{ scale: 0.95 }}
            className={`relative overflow-hidden ${className}`}
        >
            <motion.span style={{ x: textX, y: textY }} className="relative z-10 block">
                {children}
            </motion.span>
        </motion.button>
    );
};

// 3. 滚动卡片 (Scroll Cards)
const FeatureCard = ({ title, desc, index, icon }: { title: string, desc: string, index: number, icon: string }) => {
    return (
        <motion.div
            initial={{ opacity: 0, y: 50, rotateX: 10 }}
            whileInView={{ opacity: 1, y: 0, rotateX: 0 }}
            viewport={{ once: true, margin: "-100px" }}
            transition={{ duration: 0.8, delay: index * 0.1, type: "spring", bounce: 0.4 }}
            whileHover={{ y: -10, boxShadow: "0 20px 40px -10px rgba(0,0,0,0.1)" }}
            className="group relative bg-white/60 backdrop-blur-xl border border-white/80 p-8 rounded-[2rem] shadow-sm hover:shadow-xl transition-all duration-500 overflow-hidden"
        >
            <div className="absolute inset-0 bg-gradient-to-br from-white/80 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
            
            <div className="relative z-10">
                <div className="size-16 rounded-2xl bg-gradient-to-br from-[#FF9A9E] to-[#FECFEF] flex items-center justify-center mb-6 shadow-inner text-white transform group-hover:scale-110 group-hover:rotate-3 transition-all duration-500">
                    <span className="material-symbols-outlined text-3xl">{icon}</span>
                </div>
                <h3 className="text-2xl font-bold text-slate-800 mb-3">{title}</h3>
                <p className="text-slate-500 leading-relaxed font-medium">{desc}</p>
            </div>
        </motion.div>
    );
};

const HomePage: React.FC = () => {
    const navigate = useNavigate();
    const { scrollY } = useScroll();
    const [lang, setLang] = useState<'en' | 'zh'>('en');
    const t = translations[lang];
    
    // 视差文字
    const yText = useTransform(scrollY, [0, 500], [0, 150]);
    const opacityText = useTransform(scrollY, [0, 300], [1, 0]);

    return (
        <div className="min-h-screen font-sans selection:bg-orange-200 selection:text-orange-900 text-slate-900">
            <LiquidBackground />

            {/* Navigation / Header */}
            <nav className="fixed top-0 left-0 right-0 z-50 px-6 py-6 flex justify-between items-center max-w-7xl mx-auto">
                <motion.div 
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    className="flex items-center gap-2"
                >
                    <span className="text-xl font-bold tracking-tight text-slate-900">MemoryFlow</span>
                </motion.div>

                <motion.div 
                    initial={{ opacity: 0, x: 20 }}
                    animate={{ opacity: 1, x: 0 }}
                    className="flex items-center gap-4"
                >
                    <button
                        onClick={() => setLang(lang === 'en' ? 'zh' : 'en')}
                        className="px-4 py-2 rounded-full text-sm font-medium text-slate-600 hover:bg-white/50 transition-colors flex items-center gap-1"
                    >
                        <span className="material-symbols-outlined text-lg">translate</span>
                        {lang === 'en' ? 'EN' : '中'}
                    </button>
                    <div className="w-px h-6 bg-slate-300 mx-1"></div>
                    <button 
                        onClick={() => navigate('/login')}
                        className="px-6 py-2.5 rounded-full text-sm font-bold text-slate-600 hover:text-slate-900 transition-colors"
                    >
                        {t.signIn}
                    </button>
                    <MagneticButton 
                        onClick={() => navigate('/home')}
                        className="px-8 py-3 rounded-full bg-slate-900 text-white text-sm font-bold shadow-lg hover:shadow-slate-900/30 transition-shadow"
                    >
                        {t.getStarted}
                    </MagneticButton>
                </motion.div>
            </nav>

            {/* Hero Section */}
            <section className="relative z-10 min-h-screen flex flex-col justify-center items-center px-4 pt-20 overflow-hidden">
                <motion.div 
                    style={{ y: yText, opacity: opacityText }}
                    className="text-center max-w-6xl mx-auto relative"
                >
                    {/* 装饰性文字背景 */}
                    <span className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-[12vw] font-black text-slate-900/[0.03] pointer-events-none select-none leading-none whitespace-nowrap blur-sm">
                        MEMORY
                    </span>

                    <motion.div
                        initial={{ opacity: 0, y: 30 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ duration: 0.8, ease: "easeOut" }}
                    >
                        <h1 className="text-6xl md:text-8xl lg:text-9xl font-black tracking-tighter mb-8 leading-[0.9] text-slate-900">
                            <span className="block overflow-hidden">
                                <motion.span 
                                    initial={{ y: "100%" }}
                                    animate={{ y: 0 }}
                                    transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
                                    className="block"
                                >
                                    {t.capture}
                                </motion.span>
                            </span>
                            <span className="block overflow-hidden text-transparent bg-clip-text bg-gradient-to-r from-orange-400 via-pink-500 to-purple-500 pb-4">
                                <motion.span 
                                    initial={{ y: "100%" }}
                                    animate={{ y: 0 }}
                                    transition={{ duration: 0.8, delay: 0.1, ease: [0.16, 1, 0.3, 1] }}
                                    className="block"
                                >
                                    {t.flow}
                                </motion.span>
                            </span>
                            <span className="block overflow-hidden">
                                <motion.span 
                                    initial={{ y: "100%" }}
                                    animate={{ y: 0 }}
                                    transition={{ duration: 0.8, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
                                    className="block"
                                >
                                    {t.master}
                                </motion.span>
                            </span>
                        </h1>
                    </motion.div>

                    <motion.p 
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        transition={{ delay: 0.6, duration: 1 }}
                        className="text-xl md:text-2xl text-slate-500 font-medium max-w-2xl mx-auto mb-16 leading-relaxed"
                    >
                        {lang === 'en' ? (
                            <>
                                The intelligent knowledge management system that adapts to your mind. 
                                Experience the <span className="text-slate-900 font-bold decoration-orange-300 decoration-4 underline underline-offset-4">flow state</span> of learning.
                            </>
                        ) : (
                            <>
                                适应你思维的智能知识管理系统。体验学习的<span className="text-slate-900 font-bold decoration-orange-300 decoration-4 underline underline-offset-4">心流状态</span>。
                            </>
                        )}
                    </motion.p>

                    <div className="flex flex-col sm:flex-row items-center justify-center gap-6">
                        <MagneticButton 
                            onClick={() => navigate('/home')}
                            className="group px-10 py-5 rounded-full bg-slate-900 text-white text-lg font-bold shadow-2xl hover:bg-slate-800 transition-colors"
                        >
                            <span className="flex items-center gap-3">
                                {t.startJourney}
                                <span className="material-symbols-outlined group-hover:translate-x-1 transition-transform bg-white text-slate-900 rounded-full p-0.5 text-base">arrow_forward</span>
                            </span>
                        </MagneticButton>
                    </div>
                </motion.div>

                {/* 3D 悬浮展示 (模拟) */}
                <motion.div 
                    initial={{ opacity: 0, y: 100, rotateX: 20 }}
                    animate={{ opacity: 1, y: 0, rotateX: 0 }}
                    transition={{ delay: 0.5, duration: 1.2, type: "spring" }}
                    className="relative w-full max-w-5xl mt-20 perspective-1000"
                >
                    <div className="relative rounded-[2rem] overflow-hidden shadow-[0_50px_100px_-20px_rgba(50,50,93,0.15)] border-4 border-white/50 bg-white/80 backdrop-blur-md transform-style-3d rotate-x-12 hover:rotate-x-0 transition-transform duration-1000 ease-out">
                         {/* 模拟界面 Header */}
                         <div className="h-12 border-b border-slate-100 flex items-center px-6 gap-2 bg-white/50">
                            <div className="size-3 rounded-full bg-red-400/60"></div>
                            <div className="size-3 rounded-full bg-amber-400/60"></div>
                            <div className="size-3 rounded-full bg-green-400/60"></div>
                         </div>
                         {/* 模拟界面内容 */}
                         <div className="p-10 grid grid-cols-12 gap-8 h-[500px] bg-gradient-to-br from-slate-50 to-white">
                            <div className="col-span-3 space-y-4">
                                <div className="h-8 w-3/4 bg-slate-200/50 rounded-lg animate-pulse"></div>
                                <div className="h-4 w-1/2 bg-slate-100 rounded animate-pulse"></div>
                                <div className="space-y-2 mt-8">
                                    {[1,2,3,4].map(i => (
                                        <div key={i} className="h-10 w-full bg-slate-100/80 rounded-xl"></div>
                                    ))}
                                </div>
                            </div>
                            <div className="col-span-9 space-y-6">
                                <div className="flex gap-4">
                                    <div className="h-32 flex-1 bg-orange-50 rounded-2xl border border-orange-100 p-6 flex flex-col justify-between relative overflow-hidden group">
                                        <div className="absolute -right-4 -top-4 size-20 bg-orange-200/30 rounded-full group-hover:scale-150 transition-transform duration-700"></div>
                                        <div className="size-10 rounded-lg bg-orange-100 text-orange-600 flex items-center justify-center font-bold">85%</div>
                                        <div className="font-bold text-slate-800">{t.retentionRate}</div>
                                    </div>
                                    <div className="h-32 flex-1 bg-pink-50 rounded-2xl border border-pink-100 p-6 flex flex-col justify-between relative overflow-hidden group">
                                         <div className="absolute -right-4 -top-4 size-20 bg-pink-200/30 rounded-full group-hover:scale-150 transition-transform duration-700"></div>
                                         <div className="size-10 rounded-lg bg-pink-100 text-pink-600 flex items-center justify-center font-bold">12</div>
                                         <div className="font-bold text-slate-800">{t.activeGoals}</div>
                                    </div>
                                    <div className="h-32 flex-1 bg-purple-50 rounded-2xl border border-purple-100 p-6 flex flex-col justify-between relative overflow-hidden group">
                                         <div className="absolute -right-4 -top-4 size-20 bg-purple-200/30 rounded-full group-hover:scale-150 transition-transform duration-700"></div>
                                         <div className="size-10 rounded-lg bg-purple-100 text-purple-600 flex items-center justify-center font-bold">∞</div>
                                         <div className="font-bold text-slate-800">{t.possibilities}</div>
                                    </div>
                                </div>
                                <div className="h-64 bg-white rounded-2xl border border-slate-100 shadow-sm p-6 relative overflow-hidden">
                                    <div className="absolute inset-0 bg-[url('https://grainy-gradients.vercel.app/noise.svg')] opacity-10"></div>
                                    <div className="flex items-end gap-4 h-full pb-4 px-4 justify-between">
                                        {[40, 65, 45, 80, 55, 90, 70].map((h, i) => (
                                            <motion.div 
                                                key={i}
                                                initial={{ height: 0 }}
                                                whileInView={{ height: `${h}%` }}
                                                transition={{ delay: 0.8 + i * 0.1, duration: 1, type: "spring" }}
                                                className="w-full bg-slate-900 rounded-t-lg opacity-80 hover:opacity-100 hover:bg-gradient-to-t hover:from-orange-400 hover:to-pink-500 transition-all cursor-pointer"
                                            ></motion.div>
                                        ))}
                                    </div>
                                </div>
                            </div>
                         </div>
                    </div>
                </motion.div>
            </section>

            {/* Scrolling Ticker (品牌/关键词滚动) */}
            <div className="relative z-10 py-12 bg-white/50 backdrop-blur-sm border-y border-slate-200/50 overflow-hidden">
                <motion.div 
                    animate={{ x: ["0%", "-50%"] }}
                    transition={{ duration: 30, repeat: Infinity, ease: "linear" }}
                    className="flex whitespace-nowrap gap-20 text-6xl font-black text-slate-200 select-none"
                >
                    {["FOCUS", "LEARN", "GROW", "MASTER", "FLOW", "FOCUS", "LEARN", "GROW", "MASTER", "FLOW"].map((word, i) => (
                        <span key={i} className="hover:text-transparent hover:bg-clip-text hover:bg-gradient-to-r hover:from-orange-400 hover:to-pink-500 transition-colors duration-500 cursor-default">
                            {word}
                        </span>
                    ))}
                </motion.div>
            </div>

            {/* Features Section */}
            <section className="relative z-10 py-32 px-4 max-w-7xl mx-auto">
                <div className="text-center mb-24">
                    <motion.span 
                        initial={{ opacity: 0, y: 20 }}
                        whileInView={{ opacity: 1, y: 0 }}
                        className="px-4 py-2 rounded-full bg-orange-100 text-orange-600 font-bold text-sm tracking-wide uppercase"
                    >
                        {t.whyMemoryFlow}
                    </motion.span>
                    <motion.h2 
                        initial={{ opacity: 0, y: 20 }}
                        whileInView={{ opacity: 1, y: 0 }}
                        transition={{ delay: 0.1 }}
                        className="text-4xl md:text-5xl font-black mt-6 text-slate-900"
                    >
                        {t.engineeredFor} <br/>
                        <span className="text-transparent bg-clip-text bg-gradient-to-r from-orange-500 to-pink-600">{t.cognitiveExcellence}</span>
                    </motion.h2>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
                    {t.features.map((feature, index) => (
                        <FeatureCard key={index} {...feature} index={index} />
                    ))}
                </div>
            </section>

            {/* Call to Action */}
            <section className="relative z-10 py-32 px-4">
                <div className="max-w-5xl mx-auto relative">
                    <div className="absolute inset-0 bg-gradient-to-r from-orange-200 to-pink-200 blur-[100px] opacity-50 rounded-full"></div>
                    <motion.div 
                        initial={{ scale: 0.9, opacity: 0 }}
                        whileInView={{ scale: 1, opacity: 1 }}
                        transition={{ duration: 0.8 }}
                        className="relative bg-white/40 backdrop-blur-xl border border-white p-12 md:p-24 rounded-[3rem] text-center shadow-2xl overflow-hidden"
                    >
                        <div className="absolute top-0 left-0 w-full h-2 bg-gradient-to-r from-orange-400 via-pink-500 to-purple-500"></div>
                        
                        <h2 className="text-5xl md:text-7xl font-black text-slate-900 mb-8 tracking-tight">
                            {t.readyToFind} <br/>
                            <span className="italic font-serif text-transparent bg-clip-text bg-gradient-to-r from-orange-500 to-pink-600">{t.flowQuestion}</span>
                        </h2>
                        <p className="text-xl text-slate-600 mb-12 max-w-2xl mx-auto">
                            {t.joinThousands}
                        </p>
                        <MagneticButton 
                            onClick={() => navigate('/home')}
                            className="inline-block px-12 py-6 rounded-full bg-slate-900 text-white text-xl font-bold shadow-2xl hover:scale-105 transition-transform"
                        >
                            {t.getStartedFree}
                        </MagneticButton>
                    </motion.div>
                </div>
            </section>

            {/* Footer */}
            <footer className="relative z-10 bg-[#faf9f6] py-12 px-6 border-t border-slate-200 text-center">
                <div className="flex items-center justify-center gap-2 mb-4">
                     <span className="font-bold text-slate-900">MemoryFlow</span>
                </div>
                <p className="text-slate-400 text-sm">
                    © 2026 MemoryFlow Inc. Designed with <span className="text-pink-500">♥</span> for learners.
                </p>
            </footer>
        </div>
    );
};

export default HomePage;
