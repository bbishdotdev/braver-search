'use strict';

const DEBUG_LOGGING = false;
const BANG_REDIRECT_WINDOW_MS = 5000;
const BRAVE_SEARCH_URL = 'https://search.brave.com/search?q=';

const SEARCH_ENGINE_HOSTS = new Set([
    'google.com',
    'google.co.uk',
    'google.ca',
    'google.com.au',
    'bing.com',
    'duckduckgo.com',
    'www.google.com',
    'www.bing.com',
    'www.duckduckgo.com',
    'www.yandex.com',
    'search.yahoo.com'
]);

const SEARCH_PATHS = new Set([
    '/search',
    '/search/',
    '/web',
    '/web/'
]);

const REDIRECT_PARAM_PATTERN = /(?:^|[?&])(url|u|redirect|redirect_uri|dest|destination|target|next|continue|to)=/i;
const WRAPPER_KEYWORD_PATTERN = /(awstrack|safelinks|urldefense|doubleclick|tracking|trk|lnk|linkprotect|mailchi\.mp|mandrillapp)/i;
const PURE_URL_PATTERN = /^https?:\/\/\S+$/i;
const ENCODED_URL_PATTERN = /^https?%3a%2f%2f/i;
const DOMAIN_WITH_PATH_PATTERN = /^(?:www\.)?[\w.-]+\.[a-z]{2,}(?:[/?#].*)$/i;
const OPAQUE_TOKEN_PATTERN = /\b[A-Za-z0-9_-]{32,}\b/;
const JWT_PATTERN = /\b[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}\b/;

const enabledState = {
    loaded: false,
    value: true,
    pending: null
};

const pendingBangRedirects = new Map();

function debugLog(...args) {
    if (DEBUG_LOGGING) {
        console.log(...args);
    }
}

function isSupportedSearchEngine(url) {
    if (!SEARCH_ENGINE_HOSTS.has(url.hostname)) {
        return false;
    }

    if (url.pathname === '/' || url.pathname === '') {
        return url.searchParams.has('q');
    }

    return SEARCH_PATHS.has(url.pathname);
}

function isBraveSearchUrl(url) {
    return url.hostname === 'search.brave.com' && (url.pathname === '/search' || url.pathname === '/search/');
}

function findBangToken(query) {
    if (!query) {
        return null;
    }

    const tokens = query.trim().split(/\s+/);
    return tokens.find(token => /^![a-z0-9][a-z0-9-]*$/i.test(token))?.toLowerCase() ?? null;
}

function rememberBangRedirect(details, bangToken) {
    if (!bangToken || typeof details.tabId !== 'number' || details.tabId < 0) {
        return;
    }

    pendingBangRedirects.set(details.tabId, {
        bangToken,
        expiresAt: Date.now() + BANG_REDIRECT_WINDOW_MS
    });
}

function shouldSkipRedirectForBang(details) {
    if (typeof details.tabId !== 'number' || details.tabId < 0) {
        return false;
    }

    const pendingBangRedirect = pendingBangRedirects.get(details.tabId);
    if (!pendingBangRedirect) {
        return false;
    }

    if (pendingBangRedirect.expiresAt <= Date.now()) {
        pendingBangRedirects.delete(details.tabId);
        return false;
    }

    pendingBangRedirects.delete(details.tabId);
    return true;
}

function normalizeEnabledValue(value) {
    return typeof value === 'undefined' ? true : Boolean(value);
}

function loadEnabledState() {
    if (enabledState.loaded) {
        return Promise.resolve(enabledState.value);
    }

    if (enabledState.pending) {
        return enabledState.pending;
    }

    enabledState.pending = browser.storage.local.get('enabled')
        .then(result => {
            enabledState.value = normalizeEnabledValue(result.enabled);
            enabledState.loaded = true;
            debugLog("Braver Search: Enabled state initialized", enabledState.value);
            return enabledState.value;
        })
        .catch(error => {
            console.error("Braver Search: Failed to get enabled state", error);
            return enabledState.loaded ? enabledState.value : false;
        })
        .finally(() => {
            enabledState.pending = null;
        });

    return enabledState.pending;
}

function getEnabledState() {
    return enabledState.loaded ? Promise.resolve(enabledState.value) : loadEnabledState();
}

function trackEvent(event, properties = {}) {
    if (!browser.runtime?.sendNativeMessage) {
        console.error("Braver Search: Native messaging unavailable for analytics", { event });
        return Promise.resolve();
    }

    return browser.runtime.sendNativeMessage({
        type: 'trackEvent',
        event,
        properties
    }).catch(error => {
        console.error("Braver Search: Analytics event failed", error);
    });
}

function safeDecodeURIComponent(value) {
    try {
        return decodeURIComponent(value);
    } catch (error) {
        return value;
    }
}

function stripWrappedPunctuation(value) {
    return value
        .trim()
        .replace(/^[("'[\]{}<>]+/, '')
        .replace(/[)"'\]{}<>.,!?;:]+$/, '');
}

function isPureUrlLikeQuery(query) {
    const normalized = stripWrappedPunctuation(query);
    if (!normalized || /\s/.test(normalized)) {
        return false;
    }

    return PURE_URL_PATTERN.test(normalized)
        || ENCODED_URL_PATTERN.test(normalized)
        || DOMAIN_WITH_PATH_PATTERN.test(normalized);
}

function countUrlLikeSegments(value) {
    const matches = value.match(/https?:\/\/|https?%3a%2f%2f|www\.[\w.-]+\.[a-z]{2,}(?:\/|\?)/gi);
    return matches ? matches.length : 0;
}

function countQueryParams(value) {
    const matches = value.match(/[?&][^=\s&#]{1,40}=[^&\s#]+/g);
    return matches ? matches.length : 0;
}

function scoreWrappedQuery(query) {
    const trimmedQuery = query.trim();
    if (!trimmedQuery) {
        return 0;
    }

    const onceDecodedQuery = safeDecodeURIComponent(trimmedQuery);
    let score = 0;

    if (isPureUrlLikeQuery(trimmedQuery)) {
        score += 3;
    }

    if (onceDecodedQuery !== trimmedQuery && isPureUrlLikeQuery(onceDecodedQuery)) {
        score += 2;
    }

    if (REDIRECT_PARAM_PATTERN.test(trimmedQuery) || REDIRECT_PARAM_PATTERN.test(onceDecodedQuery)) {
        score += 2;
    }

    const nestedUrlCount = countUrlLikeSegments(trimmedQuery) + countUrlLikeSegments(onceDecodedQuery);
    if (nestedUrlCount >= 2) {
        score += 2;
    } else if (nestedUrlCount === 1) {
        score += 1;
    }

    if (WRAPPER_KEYWORD_PATTERN.test(trimmedQuery) || WRAPPER_KEYWORD_PATTERN.test(onceDecodedQuery)) {
        score += 1;
    }

    const queryParamCount = Math.max(countQueryParams(trimmedQuery), countQueryParams(onceDecodedQuery));
    if (queryParamCount >= 3) {
        score += 2;
    } else if (queryParamCount === 2) {
        score += 1;
    }

    if (OPAQUE_TOKEN_PATTERN.test(onceDecodedQuery) || JWT_PATTERN.test(onceDecodedQuery)) {
        score += 1;
    }

    if (onceDecodedQuery.length > 180) {
        score += 1;
    }

    return score;
}

function shouldSkipQuery(query) {
    return scoreWrappedQuery(query) >= 3;
}

browser.storage.onChanged?.addListener((changes, areaName) => {
    if (areaName !== 'local' || !changes.enabled) {
        return;
    }

    const oldValue = changes.enabled.oldValue;
    const newValue = changes.enabled.newValue;
    enabledState.value = normalizeEnabledValue(newValue);
    enabledState.loaded = true;

    if (oldValue === newValue || typeof newValue === 'undefined') {
        return;
    }

    debugLog("Braver Search: Enabled state changed", { oldValue, newValue });
    void trackEvent('redirect_setting_changed', {
        enabled: Boolean(newValue),
        surface: 'extension_storage'
    });
});

browser.webNavigation.onBeforeNavigate.addListener(async details => {
    if (!details.url) {
        return;
    }

    if (typeof details.frameId === 'number' && details.frameId !== 0) {
        return;
    }

    let url;
    try {
        url = new URL(details.url);
    } catch (error) {
        console.error("Braver Search: Error processing URL", error);
        return;
    }

    const searchQuery = url.searchParams.get('q');

    if (searchQuery && isBraveSearchUrl(url)) {
        const bangToken = findBangToken(searchQuery);
        if (bangToken) {
            debugLog("Braver Search: Remembering Brave bang search", {
                tabId: details.tabId,
                bangToken
            });
            rememberBangRedirect(details, bangToken);
        }
        return;
    }

    if (!isSupportedSearchEngine(url) || !searchQuery) {
        return;
    }

    const enabled = await getEnabledState();
    if (!enabled) {
        return;
    }

    if (shouldSkipRedirectForBang(details)) {
        debugLog("Braver Search: Skipping redirect for Brave bang search", {
            tabId: details.tabId
        });
        return;
    }

    if (shouldSkipQuery(searchQuery)) {
        debugLog("Braver Search: Skipping wrapped or pasted URL query", searchQuery);
        return;
    }

    const redirectUrl = BRAVE_SEARCH_URL + encodeURIComponent(searchQuery);
    debugLog("Braver Search: Attempting redirect", { tabId: details.tabId, redirectUrl });

    browser.tabs.update(details.tabId, { url: redirectUrl })
        .then(() => {
            debugLog("Braver Search: Redirect successful");
            return trackEvent('search_redirected', {
                surface: 'background_redirect'
            });
        })
        .catch(error => {
            console.error("Braver Search: Redirect failed", error);
        });
});

void loadEnabledState();
