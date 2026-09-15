'use strict';

// Only tagged setup pages participate. Ordinary searches send no messages and
// page content is never inspected. A message also wakes Safari's background page.
(() => {
    if (window.top !== window) { return; }
    const url = new URL(window.location.href);
    const id = url.searchParams.get('braver_setup');
    if (url.protocol !== 'https:' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(id || '')
        || !['/search', '/search/'].includes(url.pathname)) { return; }

    const notify = type => browser.runtime.sendMessage({ type })
        .catch(error => console.error('Braver Search: Setup page could not report its state', error));

    if (url.hostname === 'www.google.com') {
        void notify('setupTestPageReady');
    } else if (url.hostname === 'search.brave.com') {
        // DOM readiness alone is not success: keep the same completed-page
        // requirement as webNavigation.onCompleted, including after a cold start.
        if (document.readyState === 'complete') {
            void notify('setupTestPageCompleted');
        } else {
            window.addEventListener('load', () => {
                if (document.readyState === 'complete') { void notify('setupTestPageCompleted'); }
            }, { once: true });
        }
    }
})();
