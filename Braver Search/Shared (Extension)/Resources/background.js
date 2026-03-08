'use strict';

console.log("Braver Search: Background script loaded");

const BANG_REDIRECT_WINDOW_MS = 5000;

const SEARCH_ENGINE_HOSTS = [
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
    'search.yahoo.com',
    'www.yandex.com'
];

const pendingBangRedirects = new Map();

function isSupportedSearchEngine(url) {
    // Check if the hostname matches
    if (!SEARCH_ENGINE_HOSTS.some(domain => url.hostname === domain)) {
        return false;
    }
    
    // Check if this is actually a search path
    const searchPaths = ['/search', '/web'];
    // Root path needs special handling - only redirect if it has a 'q' parameter
    if (url.pathname === '/' || url.pathname === '') {
        return url.searchParams.has('q');
    }
    
    return searchPaths.some(path => url.pathname === path || url.pathname === path + '/');
}

function isBraveSearchUrl(url) {
    if (url.hostname !== 'search.brave.com') {
        return false;
    }

    return url.pathname === '/search' || url.pathname === '/search/';
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

// Function to check if redirect is enabled
async function isRedirectEnabled() {
    try {
        const result = await browser.storage.local.get('enabled');
        console.log("Braver Search: Redirect enabled?", result.enabled);
        return result.enabled || false;
    } catch (error) {
        console.error("Braver Search: Failed to get enabled state", error);
        return false;
    }
}

function trackEvent(event, properties = {}) {
    if (!browser.runtime?.sendNativeMessage) {
        console.error("Braver Search: Native messaging unavailable for analytics", { event });
        return;
    }

    const payload = {
        type: 'trackEvent',
        event,
        properties
    };

    return browser.runtime.sendNativeMessage(payload)
        .then(response => {
            console.log("Braver Search: Analytics event queued", { event, response });
            return response;
        })
        .catch(error => {
            console.error("Braver Search: Analytics event failed", error);
        });
}

browser.storage.onChanged?.addListener((changes, areaName) => {
    if (areaName !== 'local' || !changes.enabled) {
        return;
    }

    const oldValue = changes.enabled.oldValue;
    const newValue = changes.enabled.newValue;

    if (oldValue === newValue || typeof newValue === 'undefined') {
        return;
    }

    console.log("Braver Search: Enabled state changed", { oldValue, newValue });
    trackEvent('redirect_setting_changed', {
        enabled: Boolean(newValue),
        surface: 'extension_storage'
    });
});

browser.webNavigation.onBeforeNavigate.addListener(async (details) => {
    console.log("Braver Search: Navigation detected", { 
        details,
        userAgent: navigator.userAgent
    });
    
    // First check if redirect is enabled
    const enabled = await isRedirectEnabled();
    if (!enabled) {
        console.log("Braver Search: Redirect is disabled, skipping");
        return;
    }
    
    if (details.url) {
        console.log("Braver Search: URL detected", details.url);
        
        try {
            const url = new URL(details.url);
            const searchQuery = url.searchParams.get('q');

            if (searchQuery && isBraveSearchUrl(url)) {
                const bangToken = findBangToken(searchQuery);
                if (bangToken) {
                    console.log("Braver Search: Remembering Brave bang search", {
                        tabId: details.tabId,
                        bangToken
                    });
                    rememberBangRedirect(details, bangToken);
                }
                return;
            }
            
            // Skip URLs that are too complex or likely not search queries
            if (details.url.includes('%2F%2F') || url.pathname.length > 30) {
                console.log("Braver Search: Skipping complex URL", details.url);
                return;
            }
            
            // Check if this is a supported search engine domain and path
            if (!isSupportedSearchEngine(url)) {
                console.log("Braver Search: Not a supported search engine or path", {
                    hostname: url.hostname,
                    pathname: url.pathname
                });
                return;
            }

            console.log("Braver Search: Search query found", { 
                url: url.toString(), 
                hostname: url.hostname,
                pathname: url.pathname,
                searchQuery 
            });
            
            if (searchQuery) {
                if (shouldSkipRedirectForBang(details)) {
                    console.log("Braver Search: Skipping redirect for Brave bang search", {
                        tabId: details.tabId
                    });
                    return;
                }

                // More sophisticated check to distinguish URLs from legitimate searches
                const isLikelyURL = (query) => {
                    // If it's very long, likely a complex URL
                    if (query.length > 100) return true;
                    
                    // Check for encoded URL components that indicate a complex URL
                    if (query.includes('%2F%2F')) return true;
                    
                    // Check for tracking or redirect URLs
                    if (query.includes('awstrack.me')) return true;
                    if (query.includes('tracking=') || query.includes('redirect=')) return true;
                    
                    // Look for URL-like patterns, but be more lenient with searches
                    const urlPattern = /^https?:\/\/[\w\.-]+\.[a-z]{2,}(\/[\w\.-]*)*$/i;
                    if (urlPattern.test(query)) return true;
                    
                    // Check for complex URL structures (multiple paths and query params)
                    const hasMultiplePaths = (query.match(/\//g) || []).length > 2;
                    const hasMultipleQueryParams = (query.match(/[?&][^?&]+=[^?&]+/g) || []).length > 1;
                    if (hasMultiplePaths && hasMultipleQueryParams) return true;
                    
                    // Don't block queries that just happen to contain domains or technical terms
                    return false;
                };
                
                if (isLikelyURL(searchQuery)) {
                    console.log("Braver Search: Query looks like a URL, skipping", searchQuery);
                    return;
                }
                
                const searchUrl = "https://search.brave.com/search?q=";
                const redirectUrl = searchUrl + encodeURIComponent(searchQuery);
                console.log("Braver Search: Attempting redirect to", redirectUrl);

                trackEvent('search_redirected', {
                    surface: 'background_redirect'
                });
                
                browser.tabs.update(details.tabId, { url: redirectUrl })
                    .then(() => {
                        console.log("Braver Search: Redirect successful");
                    })
                    .catch(error => console.error("Braver Search: Redirect failed", error));
            } else {
                console.log("Braver Search: No search query found in URL");
            }
        } catch (error) {
            console.error("Braver Search: Error processing URL", error);
        }
    } else {
        console.log("Braver Search: No URL in navigation details", details);
    }
}); 
