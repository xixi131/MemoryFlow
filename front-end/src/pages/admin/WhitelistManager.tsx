import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Plus, Trash2, Mail, CheckCircle, Clock, X } from 'lucide-react';
import adminApis from '../../services/adminApis';

interface WhitelistItem {
    id: number;
    email: string;
    isRegistered: boolean;
    createdBy: string;
    createdAt: string;
}

const WhitelistManager: React.FC = () => {
    const [list, setList] = useState<WhitelistItem[]>([]);
    const [loading, setLoading] = useState(true);
    const [showAddModal, setShowAddModal] = useState(false);
    const [newEmails, setNewEmails] = useState('');
    const [page, setPage] = useState(1);

    const fetchList = async () => {
        setLoading(true);
        try {
            const res = await adminApis.getWhitelist(page, 20);
            if (res.data) {
                setList(res.data.records);
            }
        } catch (error) {
            console.error(error);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchList();
    }, [page]);

    const handleAdd = async () => {
        if (!newEmails.trim()) return;
        const emails = newEmails.split('\n').map(e => e.trim()).filter(e => e);
        try {
            await adminApis.addWhitelist(emails);
            setNewEmails('');
            setShowAddModal(false);
            fetchList();
        } catch (error) {
            console.error('Add failed', error);
        }
    };

    const handleRemove = async (id: number) => {
        if (!window.confirm('确定要移除该授权吗？')) return;
        try {
            await adminApis.removeWhitelist(id);
            fetchList();
        } catch (error) {
            console.error('Remove failed', error);
        }
    };

    return (
        <div className="h-full flex flex-col md:flex-row gap-6">
            {/* Left: List */}
            <div className="flex-1 bg-white dark:bg-surface-dark rounded-3xl border border-slate-200 dark:border-white/5 shadow-lg flex flex-col overflow-hidden h-[600px]">
                <div className="p-5 border-b border-slate-100 dark:border-white/5 flex justify-between items-center bg-slate-50/50 dark:bg-white/5">
                    <h3 className="font-bold text-lg text-slate-800 dark:text-white flex items-center gap-2">
                        <Mail className="size-5 text-primary" />
                        授权名单
                    </h3>
                    <div className="text-sm text-slate-500">
                        共 {list.length} 条记录
                    </div>
                </div>
                
                <div className="flex-1 overflow-y-auto p-2">
                    <div className="space-y-2">
                        {list.map((item) => (
                            <motion.div 
                                key={item.id}
                                initial={{ opacity: 0, x: -10 }}
                                animate={{ opacity: 1, x: 0 }}
                                className="group flex items-center justify-between p-3 rounded-xl hover:bg-slate-50 dark:hover:bg-white/5 border border-transparent hover:border-slate-100 dark:hover:border-white/5 transition-all"
                            >
                                <div className="flex items-center gap-3">
                                    <div className={`size-2 rounded-full ${item.isRegistered ? 'bg-green-500' : 'bg-amber-400'}`} />
                                    <span className="font-mono text-slate-700 dark:text-slate-200">{item.email}</span>
                                    {item.isRegistered ? (
                                        <span className="px-2 py-0.5 rounded text-[10px] bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400 font-bold">
                                            已注册
                                        </span>
                                    ) : (
                                        <span className="px-2 py-0.5 rounded text-[10px] bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400 font-bold">
                                            待邀请
                                        </span>
                                    )}
                                </div>
                                <button 
                                    onClick={() => handleRemove(item.id)}
                                    className="opacity-0 group-hover:opacity-100 p-2 text-slate-400 hover:text-red-500 transition-all"
                                >
                                    <Trash2 className="size-4" />
                                </button>
                            </motion.div>
                        ))}
                    </div>
                </div>
            </div>

            {/* Right: Actions */}
            <div className="w-full md:w-80 flex flex-col gap-6">
                <div className="bg-gradient-to-br from-primary to-blue-600 rounded-3xl p-6 text-white shadow-xl shadow-blue-500/20">
                    <h3 className="text-xl font-bold mb-2">添加新授权</h3>
                    <p className="text-blue-100 text-sm mb-6">允许新的邮箱地址注册系统。只有在白名单中的邮箱才能通过注册校验。</p>
                    <button 
                        onClick={() => setShowAddModal(true)}
                        className="w-full py-3 bg-white text-primary font-bold rounded-xl shadow-lg hover:shadow-xl hover:scale-[1.02] transition-all flex items-center justify-center gap-2"
                    >
                        <Plus className="size-5" />
                        批量添加
                    </button>
                </div>

                <div className="bg-white dark:bg-surface-dark rounded-3xl p-6 border border-slate-200 dark:border-white/5 shadow-lg">
                    <h4 className="font-bold text-slate-800 dark:text-white mb-4">使用说明</h4>
                    <ul className="space-y-3 text-sm text-slate-600 dark:text-slate-400">
                        <li className="flex gap-2">
                            <CheckCircle className="size-4 text-green-500 shrink-0" />
                            <span>绿点表示该邮箱已完成注册，处于活跃状态。</span>
                        </li>
                        <li className="flex gap-2">
                            <Clock className="size-4 text-amber-500 shrink-0" />
                            <span>黄点表示等待注册中，名额已预留。</span>
                        </li>
                    </ul>
                </div>
            </div>

            {/* Modal */}
            <AnimatePresence>
                {showAddModal && (
                    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm">
                        <motion.div 
                            initial={{ scale: 0.9, opacity: 0 }}
                            animate={{ scale: 1, opacity: 1 }}
                            exit={{ scale: 0.9, opacity: 0 }}
                            className="bg-white dark:bg-surface-dark w-full max-w-lg rounded-3xl shadow-2xl overflow-hidden"
                        >
                            <div className="p-6 border-b border-slate-100 dark:border-white/5 flex justify-between items-center">
                                <h3 className="text-xl font-bold text-slate-900 dark:text-white">批量添加白名单</h3>
                                <button onClick={() => setShowAddModal(false)} className="text-slate-400 hover:text-slate-600 dark:hover:text-white">
                                    <X className="size-6" />
                                </button>
                            </div>
                            <div className="p-6">
                                <p className="text-sm text-slate-500 mb-2">请输入邮箱地址，每行一个：</p>
                                <textarea
                                    value={newEmails}
                                    onChange={(e) => setNewEmails(e.target.value)}
                                    className="w-full h-48 p-4 bg-slate-50 dark:bg-black/20 rounded-xl border border-slate-200 dark:border-white/10 focus:outline-none focus:ring-2 focus:ring-primary font-mono text-sm"
                                    placeholder="user1@example.com&#10;user2@example.com"
                                />
                            </div>
                            <div className="p-6 bg-slate-50 dark:bg-white/5 flex justify-end gap-3">
                                <button 
                                    onClick={() => setShowAddModal(false)}
                                    className="px-5 py-2 rounded-xl text-slate-600 hover:bg-slate-200 dark:text-slate-300 dark:hover:bg-white/10 transition-colors"
                                >
                                    取消
                                </button>
                                <button 
                                    onClick={handleAdd}
                                    className="px-5 py-2 rounded-xl bg-primary text-white font-bold hover:bg-blue-600 transition-colors shadow-lg shadow-blue-500/30"
                                >
                                    确认添加
                                </button>
                            </div>
                        </motion.div>
                    </div>
                )}
            </AnimatePresence>
        </div>
    );
};

export default WhitelistManager;
