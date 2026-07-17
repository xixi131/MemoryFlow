import { chromium } from 'playwright';

const results = {};
const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 800, height: 400 } });

const apiCalls = [];
context.on('request', r => {
  const u = r.url();
  if (/\/(widget\/summary|todos\/|auth\/)/.test(u)) apiCalls.push(u);
});

await context.addInitScript(() => {
  const handlers = {};
  const ipcRenderer = {
    on: (ch, fn) => { (handlers[ch] = handlers[ch] || []).push(fn); },
    removeListener: (ch, fn) => { handlers[ch] = (handlers[ch] || []).filter(f => f !== fn); },
    removeAllListeners: (ch) => { handlers[ch] = []; },
    send: (...args) => { (window.__ipcSends = window.__ipcSends || []).push(args); },
  };
  window.__emitIpc = (ch, data) => (handlers[ch] || []).forEach(fn => fn({}, data));
  window.__openExternalCalls = [];
  const shell = { openExternal: (u) => window.__openExternalCalls.push(u) };
  window.require = (mod) => {
    if (mod === 'electron') return { ipcRenderer, shell };
    throw new Error('module not shimmed: ' + mod);
  };
});

const page = await context.newPage();
page.on('pageerror', e => (results.pageErrors = results.pageErrors || []).push(String(e)));

const measure = () => page.evaluate(() => {
  const divs = [...document.querySelectorAll('div')];
  const shell = divs.find(d => d.style.width && parseFloat(d.style.width) > 0 && d.style.height);
  if (!shell) return null;
  const r = shell.getBoundingClientRect();
  return { w: Math.round(r.width), h: Math.round(r.height) };
});

await page.goto('http://localhost:3000/#/widget');
await page.waitForTimeout(2500);

// 1. logged-out compact: quiet shell, no login UI
const bodyText = (await page.evaluate(() => document.body.innerText)).trim();
results.loggedOutBodyText = bodyText;
results.hasLoginText = bodyText.includes('点击登录');
results.loggedOutSize = await measure();

// 2. click island center: must not open login, must not expand
await page.mouse.click(400, 18);
await page.waitForTimeout(800);
results.afterClickSize = await measure();
results.openExternalCalls = await page.evaluate(() => window.__openExternalCalls);

// 3. music takeover while logged out
await page.evaluate(() => window.__emitIpc('music-data-update', {
  status: 'Playing', isPlaying: true, title: '测试歌曲', artist: '测试歌手',
  position: 10, duration: 200, coverUrl: '', themeColor: '#22d3ee'
}));
await page.waitForTimeout(1500);
results.musicSize = await measure();
await page.screenshot({ path: 'music-activity.png' });

// 4. click while music activity: expands to music card
await page.mouse.click(400, 18);
await page.waitForTimeout(1200);
results.expandedSize = await measure();
const expandedText = (await page.evaluate(() => document.body.innerText)).trim();
results.expandedShowsSong = expandedText.includes('测试歌曲') && expandedText.includes('测试歌手');
await page.screenshot({ path: 'music-expanded.png' });

// 5. stop music -> back to quiet shell
await page.evaluate(() => window.__emitIpc('music-data-update', { status: 'Stopped' }));
await page.waitForTimeout(1800);
results.afterStopSize = await measure();
results.afterStopText = (await page.evaluate(() => document.body.innerText)).trim();

results.loggedOutProtectedApiCalls = [...apiCalls];

// 6. logged-in sanity: token + mocked APIs -> review activity renders unchanged
const page2 = await context.newPage();
await context.route('**/widget/summary', r => r.fulfill({ json: { code: 200, data: { totalPendingReviews: 3, totalCompletedToday: 1, subjects: [] } } }));
await context.route('**/todos/stats', r => r.fulfill({ json: { code: 200, data: { pendingTasks: 2, dueToday: 1, overdueTasks: 0 } } }));
await context.route('**/todos/tasks**', r => r.fulfill({ json: { code: 200, data: [] } }));
await context.route('**/auth/me', r => r.fulfill({ json: { code: 200, data: { nickname: '同学' } } }));
await page2.addInitScript(() => localStorage.setItem('token', 'fake-token-for-test'));
await page2.goto('http://localhost:3000/#/widget');
await page2.waitForTimeout(2500);
const measure2 = () => page2.evaluate(() => {
  const divs = [...document.querySelectorAll('div')];
  const shell = divs.find(d => d.style.width && parseFloat(d.style.width) > 0 && d.style.height);
  if (!shell) return null;
  const r = shell.getBoundingClientRect();
  return { w: Math.round(r.width), h: Math.round(r.height) };
});
results.loggedInGreetingSize = await measure2();
const greetingText = (await page2.evaluate(() => document.body.innerText)).trim();
results.loggedInHasGreeting = /，同学/.test(greetingText);
// wait for the 10s greeting to clear, then the review activity should show
await page2.waitForTimeout(9500);
const loggedInText = (await page2.evaluate(() => document.body.innerText)).trim();
results.loggedInShowsReviewActivity = /复习 3 项/.test(loggedInText);
results.loggedInRestSize = await measure2();
// left-swipe on the island opens the review activity (existing gesture, must be unchanged)
await page2.mouse.move(400, 18);
await page2.waitForTimeout(300);
await page2.mouse.down();
for (let x = 395; x >= 330; x -= 5) { await page2.mouse.move(x, 18); await page2.waitForTimeout(15); }
await page2.mouse.up();
await page2.waitForTimeout(1500);
const activityText = (await page2.evaluate(() => document.body.innerText)).trim();
results.loggedInShowsReviewActivity = /复习 3 项/.test(activityText);
results.loggedInActivitySize = await measure2();
await page2.screenshot({ path: 'logged-in.png' });

console.log(JSON.stringify(results, null, 2));
await browser.close();
