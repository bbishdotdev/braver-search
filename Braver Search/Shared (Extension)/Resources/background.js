'use strict';

console.log("Braver Search: Background script loaded");

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
            
            const searchQuery = url.searchParams.get('q');
            console.log("Braver Search: Search query found", { 
                url: url.toString(), 
                hostname: url.hostname,
                pathname: url.pathname,
                searchQuery 
            });
            
            if (searchQuery) {
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
                
                browser.tabs.update(details.tabId, { url: redirectUrl })
                    .then(() => console.log("Braver Search: Redirect successful"))
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