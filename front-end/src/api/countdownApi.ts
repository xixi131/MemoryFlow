import type { CountdownEvent } from '@/types/countdown';

// Countdown events are persisted in the Electron main process config store
// via IPC. This project accesses ipcRenderer through the injected `require`
// global (see src/components/useIslandState.ts), so we mirror that pattern.
function getIpc() {
    try {
        return (window as any).require('electron').ipcRenderer;
    } catch {
        return null;
    }
}

export async function getCountdownEvents(): Promise<CountdownEvent[]> {
    const ipc = getIpc();
    if (!ipc) return [];
    const events = await ipc.invoke('get-countdown-events');
    return (events as CountdownEvent[]) || [];
}

export async function saveCountdownEvents(events: CountdownEvent[]): Promise<boolean> {
    const ipc = getIpc();
    if (!ipc) return false;
    return await ipc.invoke('save-countdown-events', events);
}
