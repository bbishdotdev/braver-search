describe('Background Script', () => {
    let navigationListener;
    let storageChangeListener;

    const flushPromises = () => new Promise(resolve => setTimeout(resolve, 0));

    async function loadBackgroundScript({ enabled = true, storageGetImplementation } = {}) {
        navigationListener = null;
        storageChangeListener = null;

        browser.webNavigation.onBeforeNavigate.addListener.mockImplementation(fn => {
            navigationListener = fn;
            return fn;
        });

        browser.storage.onChanged.addListener.mockImplementation(fn => {
            storageChangeListener = fn;
            return fn;
        });

        if (storageGetImplementation) {
            browser.storage.local.get.mockImplementation(storageGetImplementation);
        } else {
            browser.storage.local.get.mockResolvedValue({ enabled });
        }

        jest.isolateModules(() => {
            require('../../Shared (Extension)/Resources/background.js');
        });

        expect(navigationListener).toBeTruthy();
        expect(storageChangeListener).toBeTruthy();

        await flushPromises();
    }

    async function navigateToGoogleSearch(query, overrides = {}) {
        await navigationListener({
            url: `https://google.com/search?q=${encodeURIComponent(query)}`,
            ...overrides
        });
    }

    describe('native redirect entitlement gate', () => {
        it.each(['expired', 'eligible', 'unknown'])('does not redirect when native access is %s, even with the toggle on', async state => {
            await loadBackgroundScript();
            browser.runtime.sendNativeMessage.mockResolvedValue({ allowed: false, state });
            await navigateToGoogleSearch('hello');
            expect(browser.tabs.update).not.toHaveBeenCalled();
        });
        it('does not mistake a generic ok response or a JavaScript paid flag for access', async () => {
            await loadBackgroundScript();
            browser.runtime.sendNativeMessage.mockResolvedValue({ ok: true, paid: true });
            await navigateToGoogleSearch('hello');
            expect(browser.tabs.update).not.toHaveBeenCalled();
        });
        it('fails closed when the native bridge rejects', async () => {
            await loadBackgroundScript();
            browser.runtime.sendNativeMessage.mockRejectedValue(new Error('offline bridge'));
            await navigateToGoogleSearch('hello');
            expect(browser.tabs.update).not.toHaveBeenCalled();
        });
        it('rejects a fabricated setup token on the early path too', async () => {
            await loadBackgroundScript();
            browser.runtime.sendNativeMessage.mockResolvedValue({ allowed: false });
            await navigateToGoogleSearch('hello', { url: 'https://www.google.com/search?q=hello&braver_setup=12345678-1234-1234-1234-123456789abc' });
            expect(browser.tabs.update).not.toHaveBeenCalled();
            expect(browser.runtime.sendNativeMessage).toHaveBeenCalledWith(expect.objectContaining({ type: 'getRedirectAccess', properties: expect.objectContaining({ setup_query: false }) }));
        });
        it('does not pull the user back after navigating away during a native access check', async () => {
            await loadBackgroundScript();
            let release;
            browser.runtime.sendNativeMessage.mockImplementation(m => m.type === 'getRedirectAccess' ? new Promise(resolve => { release = resolve; }) : Promise.resolve({}));
            const first = navigateToGoogleSearch('hello', { tabId: 4 });
            await flushPromises();
            await navigationListener({ tabId: 4, frameId: 0, url: 'https://example.com/' });
            release({ allowed: true });
            await first;
            expect(browser.tabs.update).not.toHaveBeenCalled();
        });
        it('rechecks native access on the next navigation after expiration or refund', async () => {
            await loadBackgroundScript();
            await navigateToGoogleSearch('before expiry');
            expect(browser.tabs.update).toHaveBeenCalledTimes(1);
            browser.runtime.sendNativeMessage.mockResolvedValue({ allowed: false });
            await navigateToGoogleSearch('after expiry');
            expect(browser.tabs.update).toHaveBeenCalledTimes(1);
        });
    });

    describe('setup wake-up recovery', () => {
        const id = '12345678-1234-1234-1234-123456789abc';
        const google = `https://www.google.com/search?q=Braver+Search+setup+check&braver_setup=${id}`;
        const brave = `https://search.brave.com/search?q=Braver+Search+setup+check&braver_setup=${id}`;
        const sender = url => ({ frameId: 0, tab: { id: 3 }, url });
        const pageMessage = (type, pageSender) => {
            const listener = browser.runtime.onMessage.addListener.mock.calls.at(-1)?.[0];
            expect(listener).toBeDefined();
            return listener({ type }, pageSender);
        };

        beforeEach(() => {
            browser.runtime.sendNativeMessage.mockResolvedValue({ ok: true, allowed: true, analytics: { durablyQueued: true } });
            browser.tabs.get.mockResolvedValue({ id: 3, url: google });
        });

        it('recovers a first test when no before-navigation event arrived', async () => {
            await loadBackgroundScript();
            await pageMessage('setupTestPageReady', sender(google));
            expect(browser.tabs.update).toHaveBeenCalledTimes(1);
            expect(browser.tabs.update).toHaveBeenCalledWith(3, {
                url: `https://search.brave.com/search?q=Braver%20Search%20setup%20check&braver_setup=${id}`
            });
            expect(browser.runtime.sendNativeMessage.mock.calls.some(([m]) => m.type === 'setupTestCompleted' || m.event === 'search_redirected')).toBe(false);
        });

        it('does not delay the early redirect for an unanswered diagnostic message', async () => {
            await loadBackgroundScript();
            browser.runtime.sendNativeMessage.mockImplementation(m => m.type === 'setupTestProgress' ? new Promise(() => {}) : Promise.resolve({ ok: true, allowed: true }));
            void navigationListener({ frameId: 0, tabId: 3, url: google });
            await flushPromises();
            expect(browser.tabs.update).toHaveBeenCalledTimes(1);
        });

        it('still redirects if the native diagnostic API throws synchronously', async () => {
            await loadBackgroundScript();
            browser.runtime.sendNativeMessage.mockImplementation(m => {
                if (m.type === 'setupTestProgress') { throw new Error('Native bridge unavailable'); }
                return Promise.resolve({ ok: true, allowed: true });
            });
            await navigationListener({ frameId: 0, tabId: 3, url: google });
            expect(browser.tabs.update).toHaveBeenCalledTimes(1);
        });

        it('does not redirect twice when the early event and page message race', async () => {
            await loadBackgroundScript();
            await Promise.all([
                navigationListener({ frameId: 0, tabId: 3, url: google }),
                pageMessage('setupTestPageReady', sender(google)),
                pageMessage('setupTestPageReady', sender(google))
            ]);
            expect(browser.tabs.update).toHaveBeenCalledTimes(1);
        });

        it('respects the disabled toggle during recovery', async () => {
            await loadBackgroundScript({ enabled: false });
            await pageMessage('setupTestPageReady', sender(google));
            expect(browser.tabs.update).not.toHaveBeenCalled();
            expect(browser.runtime.sendNativeMessage).toHaveBeenCalledWith({
                type: 'setupTestProgress', properties: { test_id: id, stage: 'extension_seen', enabled: false }
            });
        });

        it('ignores expired or superseded tests rejected by the native app', async () => {
            await loadBackgroundScript();
            browser.runtime.sendNativeMessage.mockResolvedValue({ ok: false });
            await pageMessage('setupTestPageReady', sender(google));
            expect(browser.tabs.update).not.toHaveBeenCalled();
        });

        it('does not pull a tab back after the user navigates away', async () => {
            await loadBackgroundScript();
            browser.tabs.get.mockResolvedValue({ id: 3, url: 'https://example.com/' });
            await pageMessage('setupTestPageReady', sender(google));
            expect(browser.tabs.update).not.toHaveBeenCalled();
        });

        it('still recovers when Google adds unrelated URL parameters', async () => {
            await loadBackgroundScript();
            browser.tabs.get.mockResolvedValue({ id: 3, url: google + '&sourceid=safari' });
            await pageMessage('setupTestPageReady', sender(google));
            expect(browser.tabs.update).toHaveBeenCalledTimes(1);
        });

        it('recovers while the background is still loading its enabled state', async () => {
            let resolveEnabled;
            const enabled = new Promise(resolve => { resolveEnabled = resolve; });
            await loadBackgroundScript({ storageGetImplementation: key => key === 'enabled' ? enabled : Promise.resolve({}) });
            const recovery = pageMessage('setupTestPageReady', sender(google));
            expect(browser.tabs.update).not.toHaveBeenCalled();
            resolveEnabled({ enabled: true });
            await recovery;
            expect(browser.tabs.update).toHaveBeenCalledTimes(1);
        });

        it('ignores frames, untagged pages, and URLs supplied in the message payload', async () => {
            await loadBackgroundScript();
            browser.runtime.sendNativeMessage.mockClear();
            await pageMessage('setupTestPageReady', { ...sender(google), frameId: 1 });
            await pageMessage('setupTestPageReady', sender('https://www.google.com/search?q=ordinary'));
            const listener = browser.runtime.onMessage.addListener.mock.calls.at(-1)[0];
            await listener({ type: 'setupTestPageReady', url: google }, sender('https://example.com/'));
            expect(browser.tabs.update).not.toHaveBeenCalled();
            expect(browser.runtime.sendNativeMessage).not.toHaveBeenCalled();
        });

        it('accepts the loaded Brave page as completion, never the Google page', async () => {
            await loadBackgroundScript();
            browser.runtime.sendNativeMessage.mockClear();
            await pageMessage('setupTestPageCompleted', sender(google));
            expect(browser.runtime.sendNativeMessage).not.toHaveBeenCalled();
            await pageMessage('setupTestPageCompleted', sender(brave));
            expect(browser.runtime.sendNativeMessage).toHaveBeenCalledWith({
                type: 'setupTestCompleted', properties: { test_id: id }
            });
        });
    });

    describe('enabled state caching', () => {
        it('should track extension activation once when background runtime starts', async () => {
            const storage = { enabled: true };
            const storageGetImplementation = key => Promise.resolve({ [key]: storage[key] });
            browser.storage.local.get.mockImplementation(storageGetImplementation);
            browser.storage.local.set.mockImplementation(update => {
                Object.assign(storage, update);
                return Promise.resolve();
            });

            await loadBackgroundScript({
                storageGetImplementation
            });

            expect(browser.storage.local.set).toHaveBeenCalledWith({
                hasTrackedExtensionActivated: true
            });
            expect(browser.runtime.sendNativeMessage).toHaveBeenCalledWith(
                {
                    type: 'trackEvent',
                    event: 'extension_activated',
                    properties: {
                        surface: 'background_runtime'
                    }
                }
            );
        });

        it('keeps activation retryable when native storage rejects the event', async () => {
            browser.runtime.sendNativeMessage.mockImplementation(message => Promise.resolve(
                message.event === 'extension_activated' ? { analytics: { durablyQueued: false } } : {}
            ));
            await loadBackgroundScript({ enabled: true });
            expect(browser.storage.local.set).not.toHaveBeenCalledWith({ hasTrackedExtensionActivated: true });
            browser.runtime.sendNativeMessage.mockResolvedValue({ allowed: true, analytics: { durablyQueued: true } });
        });

        it('does not count a setup test as an ordinary search', async () => {
            await loadBackgroundScript({ enabled: true });
            const id = '12345678-1234-1234-1234-123456789abc';
            await navigationListener({ frameId: 0, tabId: 3,
                url: `https://www.google.com/search?q=Braver+Search+setup+check&braver_setup=${id}` });
            await flushPromises();
            expect(browser.tabs.update).toHaveBeenCalledWith(3, {
                url: `https://search.brave.com/search?q=Braver%20Search%20setup%20check&braver_setup=${id}`
            });
            expect(browser.runtime.sendNativeMessage.mock.calls.some(([message]) => message.event === 'search_redirected')).toBe(false);
            const completed = browser.webNavigation.onCompleted.addListener.mock.calls.at(-1)[0];
            completed({ frameId: 0, url: `https://search.brave.com/search?q=Braver+Search+setup+check&braver_setup=${id}` });
            expect(browser.runtime.sendNativeMessage).toHaveBeenCalledWith({
                type: 'setupTestCompleted', properties: { test_id: id }
            });
        });

        it('does not verify unrelated pages or subframes', async () => {
            await loadBackgroundScript();
            const completed = browser.webNavigation.onCompleted.addListener.mock.calls.at(-1)[0];
            browser.runtime.sendNativeMessage.mockClear();
            completed({ frameId: 1, url: 'https://search.brave.com/search?q=test' });
            completed({ frameId: 0, url: 'https://www.google.com/search?q=test' });
            completed({ frameId: 0, url: 'https://search.brave.com/search?q=test' });
            completed({ frameId: 0, url: 'invalid url' });
            expect(browser.runtime.sendNativeMessage).not.toHaveBeenCalled();
        });

        it('reports a disabled redirect toggle for the current setup test', async () => {
            await loadBackgroundScript({ enabled: false });
            const id = '12345678-1234-1234-1234-123456789abc';
            await navigationListener({ frameId: 0, tabId: 3,
                url: `https://www.google.com/search?q=Braver+Search+setup+check&braver_setup=${id}` });
            expect(browser.runtime.sendNativeMessage).toHaveBeenCalledWith({
                type: 'setupTestProgress', properties: { test_id: id, stage: 'extension_seen', enabled: false }
            });
            expect(browser.tabs.update).not.toHaveBeenCalled();
        });

        it('reports an accepted redirect without claiming the destination completed', async () => {
            await loadBackgroundScript();
            const id = '12345678-1234-1234-1234-123456789abc';
            await navigationListener({ frameId: 0, tabId: 3,
                url: `https://www.google.com/search?q=Braver+Search+setup+check&braver_setup=${id}` });
            await flushPromises();
            expect(browser.runtime.sendNativeMessage).toHaveBeenCalledWith({
                type: 'setupTestProgress', properties: { test_id: id, stage: 'redirect_requested' }
            });
            expect(browser.runtime.sendNativeMessage.mock.calls.some(([m]) => m.type === 'setupTestCompleted')).toBe(false);
        });

        it('reports a rejected redirect instead of leaving setup waiting', async () => {
            await loadBackgroundScript();
            browser.tabs.update.mockRejectedValueOnce(new Error('Navigation rejected'));
            const id = '12345678-1234-1234-1234-123456789abc';
            await navigationListener({ frameId: 0, tabId: 3,
                url: `https://www.google.com/search?q=Braver+Search+setup+check&braver_setup=${id}` });
            await flushPromises();
            expect(browser.runtime.sendNativeMessage).toHaveBeenCalledWith({
                type: 'setupTestProgress', properties: { test_id: id, stage: 'redirect_failed' }
            });
        });

        it('should redirect when enabled in storage', async () => {
            await loadBackgroundScript({ enabled: true });

            await navigateToGoogleSearch('test');
            await flushPromises();

            expect(browser.tabs.update).toHaveBeenCalledWith(
                undefined,
                { url: 'https://search.brave.com/search?q=test' }
            );
            expect(browser.runtime.sendNativeMessage).toHaveBeenCalledWith(
                {
                    type: 'trackEvent',
                    event: 'search_redirected',
                    properties: {
                        surface: 'background_redirect'
                    }
                }
            );
        });

        it('should not redirect when disabled in storage', async () => {
            await loadBackgroundScript({ enabled: false });

            await navigateToGoogleSearch('test');

            expect(browser.tabs.update).not.toHaveBeenCalled();
        });

        it('should avoid repeated storage reads after initialization', async () => {
            await loadBackgroundScript({ enabled: true });
            const initialCalls = browser.storage.local.get.mock.calls.length;

            await navigateToGoogleSearch('first');
            await flushPromises();
            await navigateToGoogleSearch('second');
            await flushPromises();

            expect(browser.storage.local.get).toHaveBeenCalledTimes(initialCalls);
        });

        it('should reuse the same pending storage read on cold start', async () => {
            let resolveStorage;
            const pendingStorageRead = new Promise(resolve => {
                resolveStorage = resolve;
            });

            await loadBackgroundScript({
                storageGetImplementation: jest.fn(() => pendingStorageRead)
            });
            const initialCalls = browser.storage.local.get.mock.calls.length;

            const navigationPromise = navigateToGoogleSearch('test');
            expect(browser.storage.local.get).toHaveBeenCalledTimes(initialCalls);

            resolveStorage({ enabled: true });
            await navigationPromise;
            await flushPromises();

            expect(browser.tabs.update).toHaveBeenCalledWith(
                undefined,
                { url: 'https://search.brave.com/search?q=test' }
            );
        });

        it('should update the cached enabled state from storage changes', async () => {
            await loadBackgroundScript({ enabled: true });

            storageChangeListener(
                {
                    enabled: {
                        oldValue: true,
                        newValue: false
                    }
                },
                'local'
            );

            await navigateToGoogleSearch('test');

            expect(browser.tabs.update).not.toHaveBeenCalled();
        });
    });

    describe('early exits', () => {
        it('should ignore unsupported hosts before reading storage again', async () => {
            await loadBackgroundScript({ enabled: true });
            const initialCalls = browser.storage.local.get.mock.calls.length;

            await navigationListener({
                url: 'https://example.com/search?q=test'
            });

            expect(browser.storage.local.get).toHaveBeenCalledTimes(initialCalls);
            expect(browser.tabs.update).not.toHaveBeenCalled();
        });

        it('should ignore non-main-frame navigations before reading storage again', async () => {
            await loadBackgroundScript({ enabled: true });
            const initialCalls = browser.storage.local.get.mock.calls.length;

            await navigationListener({
                frameId: 2,
                url: 'https://google.com/search?q=test'
            });

            expect(browser.storage.local.get).toHaveBeenCalledTimes(initialCalls);
            expect(browser.tabs.update).not.toHaveBeenCalled();
        });

        it('should not redirect Brave Search URLs', async () => {
            await loadBackgroundScript({ enabled: true });

            await navigationListener({
                url: 'https://search.brave.com/search?q=test'
            });

            expect(browser.tabs.update).not.toHaveBeenCalled();
        });

        it('should not redirect URLs without search queries', async () => {
            await loadBackgroundScript({ enabled: true });

            await navigationListener({
                url: 'https://google.com'
            });

            expect(browser.tabs.update).not.toHaveBeenCalled();
        });
    });

    describe('URL handling', () => {
        beforeEach(async () => {
            await loadBackgroundScript({ enabled: true });
        });

        describe('legitimate search queries', () => {
            const validSearchQueries = [
                'What is http',
                'http meaning',
                'What is the IP of google.com',
                'how to host website on .com domain',
                'difference between http and https',
                'best .com domain registrar',
                'what is localhost:3000',
                'how to buy domain.com',
                'http vs https security',
                'compare .com vs .org',
                'what is port 8080 used for',
                'localhost not working',
                '"https://example.com" review',
                'what is redirect_uri'
            ];

            validSearchQueries.forEach(query => {
                it(`should redirect search: "${query}"`, async () => {
                    await navigateToGoogleSearch(query);
                    await flushPromises();

                    expect(browser.tabs.update).toHaveBeenCalledWith(
                        undefined,
                        { url: `https://search.brave.com/search?q=${encodeURIComponent(query)}` }
                    );
                });
            });
        });

        describe('wrapped URLs that should not redirect', () => {
            const wrappedQueries = [
                'https://4bqs42xm.r.us-west-2.awstrack.me/L0/https:%2F%2Fstore.ui.com%2Fus%2Fen%2Forder%2Fstatus/1/123',
                'https://click.email.domain.com/tracking?id=123&url=https://shop.com',
                'https://auth.service.com/callback?token=abc123&redirect_uri=https://app.com',
                'https://nam12.safelinks.protection.outlook.com/?url=https%3A%2F%2Fexample.com%2Fmagic%3Ftoken%3Dabc123&data=some-long-signed-payload',
                'https://example.com/login?otp=123456&redirect_uri=https%3A%2F%2Fapp.example.com%2Fwelcome&token=ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890',
                'myapp://callback?code=abc123&state=xyz789',
                'https://accounts.example.com/verify#access_token=abc.def.ghi',
                'https://localhost:3000/auth/callback?code=abc123&state=xyz789'
            ];

            wrappedQueries.forEach(query => {
                it(`should skip wrapped URL query: "${query}"`, async () => {
                    await navigateToGoogleSearch(query);

                    expect(browser.tabs.update).not.toHaveBeenCalled();
                });
            });
        });

        it('should properly encode search queries', async () => {
            await navigationListener({
                url: 'https://google.com/search?q=test search'
            });
            await flushPromises();

            expect(browser.tabs.update).toHaveBeenCalledWith(
                undefined,
                { url: 'https://search.brave.com/search?q=test%20search' }
            );
        });

        it('should not block redirects when analytics fails', async () => {
            browser.runtime.sendNativeMessage.mockImplementation(m => m.type === 'getRedirectAccess' ? Promise.resolve({ allowed: true }) : Promise.reject(new Error('analytics unavailable')));

            await navigateToGoogleSearch('test');
            await flushPromises();

            expect(browser.tabs.update).toHaveBeenCalledWith(
                undefined,
                { url: 'https://search.brave.com/search?q=test' }
            );
        });

        it('should skip one redirect after a Brave bang search in the same tab', async () => {
            await navigationListener({
                tabId: 42,
                url: 'https://search.brave.com/search?q=cats%20!g'
            });

            await navigationListener({
                tabId: 42,
                url: 'https://google.com/search?q=cats'
            });

            expect(browser.tabs.update).not.toHaveBeenCalled();
        });

        it('should still redirect supported searches without a Brave bang', async () => {
            await navigationListener({
                tabId: 42,
                url: 'https://search.brave.com/search?q=cats'
            });

            await navigationListener({
                tabId: 42,
                url: 'https://google.com/search?q=cats'
            });
            await flushPromises();

            expect(browser.tabs.update).toHaveBeenCalledWith(
                42,
                { url: 'https://search.brave.com/search?q=cats' }
            );
        });

        it('should track enabled state changes from storage updates', () => {
            storageChangeListener(
                {
                    enabled: {
                        oldValue: false,
                        newValue: true
                    }
                },
                'local'
            );

            expect(browser.runtime.sendNativeMessage).toHaveBeenCalledWith(
                {
                    type: 'trackEvent',
                    event: 'redirect_setting_changed',
                    properties: {
                        enabled: true,
                        surface: 'extension_storage'
                    }
                }
            );
        });
    });
});
