describe('Background Script', () => {
    let navigationListener;
    
    beforeEach(() => {
        // Reset the navigation listener
        navigationListener = null;
        
        // Set up the listener capture
        browser.webNavigation.onBeforeNavigate.addListener.mockImplementation(fn => {
            navigationListener = fn;
            return fn;
        });
        
        // Import the background script in isolation
        jest.isolateModules(() => {
            require('../../Shared (Extension)/Resources/background.js');
        });
        
        // Verify setup
        expect(navigationListener).toBeTruthy();
    });
    
    describe('isRedirectEnabled', () => {
        it('should return true when enabled in storage', async () => {
            // Setup
            browser.storage.local.get.mockImplementation(() => Promise.resolve({ enabled: true }));
            
            // Execute
            await navigationListener({
                url: 'https://google.com/search?q=test'
            });
            
            // Verify
            expect(browser.tabs.update).toHaveBeenCalledWith(
                undefined,
                { url: 'https://search.brave.com/search?q=test' }
            );
        });
        
        it('should not redirect when disabled in storage', async () => {
            // Setup
            browser.storage.local.get.mockImplementation(() => Promise.resolve({ enabled: false }));
            
            // Execute
            await navigationListener({
                url: 'https://google.com/search?q=test'
            });
            
            // Verify
            expect(browser.tabs.update).not.toHaveBeenCalled();
        });
    });
    
    describe('URL handling', () => {
        beforeEach(() => {
            browser.storage.local.get.mockImplementation(() => Promise.resolve({ enabled: true }));
        });

        // Test legitimate search queries that contain URL-like terms
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
                'localhost not working'
            ];

            validSearchQueries.forEach(query => {
                it(`should redirect search: "${query}"`, async () => {
                    await navigationListener({
                        url: `https://google.com/search?q=${encodeURIComponent(query)}`
                    });

                    expect(browser.tabs.update).toHaveBeenCalledWith(
                        undefined,
                        { url: `https://search.brave.com/search?q=${encodeURIComponent(query)}` }
                    );
                });
            });
        });

        // Test URLs that should not be redirected
        describe('complex URLs that should not redirect', () => {
            const urlsThatShouldNotRedirect = [
                // Email tracking URLs
                'https://4bqs42xm.r.us-west-2.awstrack.me/L0/https:%2F%2Fstore.ui.com%2Fus%2Fen%2Forder%2Fstatus/1/123',
                // URLs with multiple query parameters
                'https://example.com/path?id=123&redirect=https://another.com',
                // URLs with encoded components
                'https://example.com/redirect?url=https%3A%2F%2Fgoogle.com',
                // Complex paths with dots
                'https://api.service.com/v1/users/profile.json',
                // URLs with tracking parameters
                'https://click.email.domain.com/tracking?id=123&url=https://shop.com',
                // Deep links
                'https://app.domain.com/deep/link/to/content?ref=email',
                // URLs with authentication tokens
                'https://auth.service.com/callback?token=abc123&redirect_uri=https://app.com',
                // URLs with fragments
                'https://docs.domain.com/page#section-1?source=email'
            ];

            urlsThatShouldNotRedirect.forEach(url => {
                it(`should not redirect URL: "${url}"`, async () => {
                    await navigationListener({
                        url: url
                    });

                    expect(browser.tabs.update).not.toHaveBeenCalled();
                });
            });
        });

        // Test edge cases
        describe('edge cases', () => {
            const edgeCases = [
                {
                    name: 'search query with IP address',
                    url: 'https://google.com/search?q=ping 192.168.1.1',
                    shouldRedirect: true
                },
                {
                    name: 'search about localhost',
                    url: 'https://google.com/search?q=what is localhost:8080',
                    shouldRedirect: true
                },
                {
                    name: 'search with URL in quotes',
                    url: 'https://google.com/search?q="https://example.com" review',
                    shouldRedirect: true
                },
                {
                    name: 'search about domain extensions',
                    url: 'https://google.com/search?q=.com vs .org vs .net',
                    shouldRedirect: true
                }
            ];

            edgeCases.forEach(({ name, url, shouldRedirect }) => {
                it(`should handle ${name} correctly`, async () => {
                    await navigationListener({
                        url: url
                    });

                    if (shouldRedirect) {
                        expect(browser.tabs.update).toHaveBeenCalled();
                    } else {
                        expect(browser.tabs.update).not.toHaveBeenCalled();
                    }
                });
            });
        });

        // Original test cases
        it('should not redirect Brave Search URLs', async () => {
            await navigationListener({
                url: 'https://search.brave.com/search?q=test'
            });
            
            expect(browser.tabs.update).not.toHaveBeenCalled();
        });

        it('should not redirect URLs without search queries', async () => {
            await navigationListener({
                url: 'https://google.com'
            });
            
            expect(browser.tabs.update).not.toHaveBeenCalled();
        });

        it('should properly encode search queries', async () => {
            await navigationListener({
                url: 'https://google.com/search?q=test search'
            });
            
            expect(browser.tabs.update).toHaveBeenCalledWith(
                undefined,
                { url: 'https://search.brave.com/search?q=test%20search' }
            );
        });
    });
}); 