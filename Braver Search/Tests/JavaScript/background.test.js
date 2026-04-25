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

    describe('enabled state caching', () => {
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

            const navigationPromise = navigateToGoogleSearch('test');
            expect(browser.storage.local.get).toHaveBeenCalledTimes(1);

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
            browser.runtime.sendNativeMessage.mockRejectedValueOnce(new Error('analytics unavailable'));

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
