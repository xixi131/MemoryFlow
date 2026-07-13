const { parentPort } = require('worker_threads');
const { SMTCMonitor } = require('@coooookies/windows-smtc-monitor');

let monitor = null;
let lastCoverUrl = '';
let lastThemeColor = '#22d3ee';
let lastTitle = '';
let lastThumbnailBuffer = null; // Track thumbnail buffer to detect changes
let lastPosition = null; // Track last position for play/pause detection
let lastStatus = 'Paused'; // Track last reported status
let unchangedCount = 0; // Count consecutive unchanged positions
let lastEmittedPayload = null;

const EVENT_THROTTLE_MS = 180;
const POLLING_INTERVAL_MS = 1000;

// Position estimator for apps that don't provide SMTC timeline (e.g., NetEase Cloud Music)
let posEstimator = {
    title: '',              // Current song title
    accumulatedSec: 0,      // Accumulated playback seconds
    lastTickTime: 0,        // Timestamp of last tick
    active: false,          // Whether estimation mode is on
    playingConfirmedCount: 0,// Consecutive Playing polls (wait for actual playback)
    lastSeenUpdateTime: 0,  // Track session.lastUpdatedTime to detect seek events
};

// 动态导入 Vibrant (处理不同版本的 API)
let Vibrant = null;
try {
    const vNode = require('node-vibrant/node');
    // node-vibrant v4 exports { Vibrant } as named export
    Vibrant = vNode.Vibrant || vNode.default || vNode;
    log('[MusicWorker] node-vibrant loaded successfully');
} catch (e) {
    console.warn('[MusicWorker] Failed to load node-vibrant/node, trying fallback...', e.message);
    try {
        const vLib = require('node-vibrant');
        Vibrant = vLib.Vibrant || vLib.default || vLib;
        log('[MusicWorker] node-vibrant (fallback) loaded successfully');
    } catch (e2) {
        console.warn('[MusicWorker] node-vibrant not available:', e2.message);
    }
}

function log(msg) {
    parentPort.postMessage({ type: 'log', data: msg });
}

function error(msg) {
    parentPort.postMessage({ type: 'error', data: msg });
}

function sendData(data) {
    parentPort.postMessage({ type: 'music-data', data });
}

function shouldEmitPayload(nextPayload) {
    if (!nextPayload || typeof nextPayload !== 'object') return false;
    if (!lastEmittedPayload) return true;

    const prev = lastEmittedPayload;
    if (nextPayload.status !== prev.status) return true;
    if (nextPayload.isPlaying !== prev.isPlaying) return true;
    if (nextPayload.title !== prev.title) return true;
    if (nextPayload.artist !== prev.artist) return true;
    if (nextPayload.coverUrl !== prev.coverUrl) return true;
    if (nextPayload.themeColor !== prev.themeColor) return true;
    if (Number(nextPayload.duration || 0) !== Number(prev.duration || 0)) return true;

    const nextPos = Number(nextPayload.position || 0);
    const prevPos = Number(prev.position || 0);
    if (Math.abs(nextPos - prevPos) >= 1) return true;

    return false;
}

// 异步提取主题色
async function extractThemeColor(buffer) {
    if (!Vibrant || !Buffer.isBuffer(buffer)) {
        return lastThemeColor;
    }

    try {
        // 尝试不同的 Vibrant API
        let palette;
        if (typeof Vibrant === 'function') {
            // new Vibrant(buffer).getPalette()
            const v = new Vibrant(buffer);
            palette = await v.getPalette();
        } else if (Vibrant.from) {
            // Vibrant.from(buffer).getPalette()
            palette = await Vibrant.from(buffer).getPalette();
        } else if (Vibrant.default) {
            // ES Module default export
            const v = new Vibrant.default(buffer);
            palette = await v.getPalette();
        } else {
            return lastThemeColor;
        }

        const hex = palette?.Vibrant?.hex || palette?.DarkVibrant?.hex || palette?.Muted?.hex || '#22d3ee';
        return hex;
    } catch (e) {
        // Log error but fallback to default color
        console.error('[MusicWorker] Theme color extraction failed:', e);
        return lastThemeColor;
    }
}

function initMonitor() {
    try {
        log('Initializing SMTCMonitor in Worker...');
        monitor = new SMTCMonitor();

        const sendUpdate = async (sourceId) => {
            // 获取当前所有会话
            let sessions = [];
            try {
                sessions = SMTCMonitor.getMediaSessions();
            } catch (e) {
                error('Failed to get media sessions: ' + e.message);
                return;
            }

            // 优先选择正在播放的会话 - 检查多种状态码
            // Windows SMTC 状态: 0=Closed, 1=Opened, 2=Changing, 3=Stopped, 4=Playing, 5=Paused
            // 某些播放器可能返回不同的值或 undefined
            const session = sessions.find(s => {
                const st = s.playback?.playbackStatus;  // FIXED: 使用正确的字段名
                return st === 4 || st === 'Playing' || st === 1 || st === 2;
            }) || sessions.find(s => s.media?.title) || sessions[0];

            if (!session) {
                // 如果没有找到会话（音乐软件关闭），且上次状态不是停止，则发送停止状态
                // 这样前端可以立即切换回“复习提醒”模式
                if (lastStatus !== 'Stopped') {
                    const payload = {
                        title: '',
                        artist: '',
                        status: 'Stopped',
                        isPlaying: false,
                        coverUrl: '',
                        themeColor: '#22d3ee',
                        position: 0,
                        duration: 0,
                        lastUpdate: Date.now()
                    };
                    lastStatus = 'Stopped';
                    lastTitle = '';
                    lastThumbnailBuffer = null;
                    lastEmittedPayload = null;
                    log('[MusicWorker] 检测到无活动会话，发送 Stopped 状态');
                    sendData(payload);
                }
                return;
            }

            // 获取时间轴信息 (position 和 duration 都是秒) - 使用原始浮点数比较
            const rawPosition = session.timeline?.position || 0;
            const duration = session.timeline?.duration || session.timeline?.endTime || 240;

            // Only log if timeline is empty (NetEase Cloud Music issue)
            if (rawPosition === 0 && duration === 0 && session.timeline) {
                log(`⚠️ Warning: Empty timeline data from ${session.sourceAppId || 'unknown app'}`);
            }

            // 状态映射 - 处理各种可能的状态值
            let status = 'Stopped';
            const pbStatus = session.playback?.playbackStatus;  // FIXED: 使用正确的字段名

            // Playback status check (no logging to reduce noise)

            // 直接检查数值状态
            if (pbStatus === 4 || pbStatus === 'Playing') {
                status = 'Playing';
            } else if (pbStatus === 5 || pbStatus === 'Paused') {
                status = 'Paused';
            } else if (pbStatus === undefined || pbStatus === null) {
                // 如果状态未定义，通过检测 position 是否在变化来判断
                if (session.media?.title) {
                    // 使用稳定性检测：连续2次位置不变才认为暂停
                    if (lastPosition !== null) {
                        // 使用原始浮点数比较，避免 Math.floor 导致的误判
                        const positionDiff = Math.abs(rawPosition - lastPosition);

                        if (positionDiff > 0.1) {  // 位置变化超过 0.1 秒
                            // 位置变化 = 正在播放
                            status = 'Playing';
                            unchangedCount = 0;
                        } else {
                            // 位置基本不变
                            unchangedCount++;
                            // 如果连续2次不变，认为是暂停；否则保持上次状态
                            if (unchangedCount >= 2) {
                                status = 'Paused';
                            } else {
                                status = lastStatus; // 保持上次状态
                            }
                        }
                    } else {
                        // 首次检测，假设暂停
                        status = 'Paused';
                    }
                }
            } else if (typeof pbStatus === 'number' && pbStatus > 0 && pbStatus < 4) {
                // 1=Opened, 2=Changing, 3=Stopped - 可能还没开始播放
                status = 'Paused';
            }

            // 更新上次位置和状态（使用原始浮点数）
            lastPosition = rawPosition;
            lastStatus = status;

            const isPlaying = status === 'Playing';
            let coverUrl = lastCoverUrl;
            let themeColor = lastThemeColor;

            // 检查是否需要更新封面
            // 逻辑: 只有当封面数据实际发生变化时，或者标题变化且之前无封面时，才更新
            // 这样可以解决 Windows SMTC 延迟更新封面导致的封面不匹配问题
            const currentThumbnail = session.media?.thumbnail;
            let shouldUpdateCover = false;

            if (Buffer.isBuffer(currentThumbnail)) {
                // 如果当前有封面
                if (!lastThumbnailBuffer || !currentThumbnail.equals(lastThumbnailBuffer)) {
                    // 且与上次不同（或者是第一次）
                    shouldUpdateCover = true;
                }
            } else {
                // 当前没封面
                if (lastThumbnailBuffer) {
                    // 之前有 -> 变成了没有
                    shouldUpdateCover = true;
                }
            }

            // 如果标题变了，更新标题
            if (session.media?.title !== lastTitle) {
                lastTitle = session.media?.title;
                // 注意：这里我们不再强制重置封面，因为可能切歌时封面数据还没变
                // 如果封面数据还没变，我们暂时显示旧封面，等到封面数据变了（shouldUpdateCover=true）再更新
            }

            if (shouldUpdateCover) {
                if (Buffer.isBuffer(currentThumbnail)) {
                    lastThumbnailBuffer = currentThumbnail;
                    lastCoverUrl = `data:image/png;base64,${currentThumbnail.toString('base64')}`;

                    // 异步提取主题色 (使用 await 确保第一时间发送正确的颜色)
                    try {
                        lastThemeColor = await extractThemeColor(currentThumbnail);
                    } catch (e) {
                        console.error('[MusicWorker] Color extraction error:', e);
                        // 出错时保持旧颜色，或者可以使用默认颜色
                    }
                } else {
                    // 封面消失了
                    lastThumbnailBuffer = null;
                    lastCoverUrl = '';
                    lastThemeColor = '#22d3ee';
                }
            }

            // 使用更新后的值
            coverUrl = lastCoverUrl;
            themeColor = lastThemeColor;

            // === Position Estimation for apps without SMTC timeline ===
            let finalPosition = rawPosition;
            const currentSongTitle = session.media?.title || '';

            if (rawPosition > 0) {
                // App provides real position (e.g., Apple Music) → use it directly
                if (posEstimator.active) {
                    posEstimator.active = false;
                }
                posEstimator.title = currentSongTitle;
            } else if (currentSongTitle && duration > 0) {
                // Position is 0 → this app doesn't update SMTC timeline
                const sessionUpdateTime = session.lastUpdatedTime || 0;

                if (currentSongTitle !== posEstimator.title) {
                    // Song changed → reset estimator
                    posEstimator.title = currentSongTitle;
                    posEstimator.accumulatedSec = 0;
                    posEstimator.lastTickTime = Date.now();
                    posEstimator.playingConfirmedCount = 0;
                    posEstimator.lastSeenUpdateTime = sessionUpdateTime;
                    posEstimator.active = true;
                    log(`[PosEstimator] New song: "${currentSongTitle}", waiting for playback confirmation...`);
                }

                // Detect seek events: if lastUpdatedTime changed significantly,
                // it may indicate the user dragged the progress bar
                if (posEstimator.active && posEstimator.lastSeenUpdateTime > 0 && sessionUpdateTime > 0) {
                    const updateTimeDiff = Math.abs(sessionUpdateTime - posEstimator.lastSeenUpdateTime);
                    // If lastUpdatedTime jumped by more than 2 seconds, a seek or state change happened
                    if (updateTimeDiff > 2000 && posEstimator.playingConfirmedCount > 0) {
                        // We can't know the exact new position, but we know something changed
                        // Log for diagnostics
                        log(`[PosEstimator] Detected possible seek (lastUpdatedTime jumped by ${(updateTimeDiff / 1000).toFixed(1)}s)`);
                    }
                }
                posEstimator.lastSeenUpdateTime = sessionUpdateTime;

                if (posEstimator.active) {
                    const now = Date.now();

                    if (isPlaying) {
                        // Require 3 consecutive Playing polls (~1.5s) before advancing
                        // This prevents premature progress during network buffering
                        posEstimator.playingConfirmedCount++;

                        if (posEstimator.playingConfirmedCount >= 3) {
                            // Playback confirmed → accumulate time
                            if (posEstimator.lastTickTime > 0) {
                                const deltaSec = (now - posEstimator.lastTickTime) / 1000;
                                // Guard against large jumps (system sleep, etc.)
                                if (deltaSec > 0 && deltaSec < 5) {
                                    posEstimator.accumulatedSec = Math.min(
                                        posEstimator.accumulatedSec + deltaSec,
                                        duration
                                    );
                                }
                            }
                        }
                    } else {
                        // Paused → freeze accumulated time, reset confirmation
                        posEstimator.playingConfirmedCount = 0;
                    }

                    posEstimator.lastTickTime = now;
                    finalPosition = posEstimator.accumulatedSec;
                }
            }

            const payload = {
                title: session.media?.title || '未知歌曲',
                artist: session.media?.artist || '未知歌手',
                status,
                isPlaying,
                coverUrl: coverUrl || '',
                themeColor: themeColor || '#22d3ee',
                position: Math.floor(finalPosition),
                duration: Math.floor(duration),
                lastUpdate: Date.now()
            };

            if (shouldEmitPayload(payload)) {
                lastEmittedPayload = { ...payload };
                sendData(payload);
            }
        };

        const throttle = (func, limit) => {
            let inThrottle;
            return function () {
                const args = arguments;
                const context = this;
                if (!inThrottle) {
                    func.apply(context, args);
                    inThrottle = true;
                    setTimeout(() => inThrottle = false, limit);
                }
            }
        }

        const throttledSend = throttle((id) => sendUpdate(id), EVENT_THROTTLE_MS);

        // Timeline events can be very frequent when dragging progress bars.
        monitor.on('session-timeline-changed', (sourceAppId) => {
            throttledSend(sourceAppId);
        });
        monitor.on('session-media-changed', throttledSend);
        monitor.on('session-playback-changed', throttledSend);
        monitor.on('current-session-changed', throttledSend);
        monitor.on('session-added', throttledSend);

        // 初始化时发送一次，然后按更低频率轮询，降低线程和 IPC 压力。
        setTimeout(() => sendUpdate(null), 300);
        setInterval(() => sendUpdate(null), POLLING_INTERVAL_MS);

        log('SMTCMonitor started successfully');

    } catch (e) {
        error('Failed to start monitor: ' + e.message);
        setTimeout(initMonitor, 2000);
    }
}

// 监听来自主线程的消息
parentPort.on('message', (message) => {
    if (message.type === 'seek') {
        const position = message.position;
        log(`收到 seek 指令: ${position} 秒`);

        // 注意: Windows SMTC API 大多数情况下不支持直接 seek
        // 但某些播放器可能支持通过 SendInput 发送键盘快捷键
        // 这里我们记录日志，前端会在UI上立即更新位置
        // 真正的 seek 需要依赖播放器自身的 API

        // 尝试获取当前会话并查看是否支持 seek
        try {
            const sessions = SMTCMonitor.getMediaSessions();
            const session = sessions.find(s => s.playback?.status === 4) || sessions[0];
            if (session) {
                log(`当前会话: ${session.media?.title}, 尝试 seek 到 ${position}s`);
                // Windows SMTC 不直接支持 seek，但可以尝试
                // 某些播放器可能通过 timeline 支持
            }
        } catch (e) {
            error('Seek 尝试失败: ' + e.message);
        }
    }
});

// Start immediately
initMonitor();
