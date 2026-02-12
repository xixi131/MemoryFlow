const getApiOrigin = (): string | null => {
    const raw = (import.meta as any)?.env?.VITE_API_BASE_URL;
    if (typeof raw !== 'string' || raw.trim() === '') return null;
    const normalized = raw.trim().replace(/\/+$/, '');
    try {
        return new URL(normalized).origin;
    } catch {
        return null;
    }
};

export const resolveApiAssetUrl = (input?: string | null): string => {
    if (!input) return '';
    const value = input.trim();
    if (!value) return '';

    const apiOrigin = getApiOrigin();

    if (value.startsWith('/api/')) {
        return apiOrigin ? `${apiOrigin}${value}` : value;
    }

    if (value.startsWith('/uploads/')) {
        return apiOrigin ? `${apiOrigin}/api${value}` : value;
    }

    if (value.startsWith('/')) {
        return apiOrigin ? `${apiOrigin}${value}` : value;
    }

    if (!/^https?:\/\//i.test(value)) {
        return value;
    }

    if (!apiOrigin) return value;

    try {
        const u = new URL(value);
        const api = new URL(apiOrigin);
        const isLocalHost = u.hostname === '127.0.0.1' || u.hostname === 'localhost' || u.hostname === '0.0.0.0';
        const isDifferentHost = u.host !== api.host;

        if (isLocalHost || isDifferentHost || u.protocol !== api.protocol) {
            return `${apiOrigin}${u.pathname}${u.search}${u.hash}`;
        }

        return value;
    } catch {
        return value;
    }
};
