/**
 * @jest-environment jsdom
 */

describe('Popup Script', () => {
    let toggleButton;
    let reviewLink;
    let supportCard;
    let supportLink;
    
    beforeEach(() => {
        // Set up our document body
        document.body.innerHTML = `
            <h1 id="redirectTitle"></h1><p id="redirectDescription"></p>
            <label id="redirectToggle"><input type="checkbox" id="toggleButton"></label>
            <a id="accessLink"></a>
            <section id="accessCard" class="hidden"><h2 id="accessTitle"></h2><p id="accessMessage"></p></section>
            <a id="reviewLink" href="#"></a>
            <section id="supportCard" class="hidden"></section>
            <a id="supportLink" href="#" class="hidden"><span>Give Thanks!</span></a>
        `;
        
        toggleButton = document.getElementById('toggleButton');
        reviewLink = document.getElementById('reviewLink');
        supportCard = document.getElementById('supportCard');
        supportLink = document.getElementById('supportLink');
        
        // Clear all mocks
        jest.clearAllMocks();
        
        // Import the popup script
        require('../../Shared (Extension)/Resources/popup.js');
    });
    
    describe('Initial state', () => {
        it('explains expired access even when the redirect toggle is on', async () => {
            browser.storage.local.get.mockResolvedValue({ enabled: true });
            browser.runtime.sendNativeMessage.mockResolvedValue({ accessAllowed: false, userState: 'expired' });
            document.dispatchEvent(new Event('DOMContentLoaded'));
            await new Promise(resolve => setTimeout(resolve, 0));
            expect(document.getElementById('accessCard').classList.contains('hidden')).toBe(false);
            expect(document.getElementById('redirectTitle').textContent).toBe('Redirects paused');
            expect(document.getElementById('accessLink').textContent).toBe('See lifetime prices');
            expect(document.getElementById('redirectToggle').classList.contains('hidden')).toBe(true);
            expect(browser.storage.local.set).not.toHaveBeenCalled();
        });
        it('explains the trial requirement without changing the saved redirect preference', async () => {
            browser.storage.local.get.mockResolvedValue({ enabled: true });
            browser.runtime.sendNativeMessage.mockResolvedValue({ accessAllowed: false, userState: 'eligible' });
            document.dispatchEvent(new Event('DOMContentLoaded'));
            await new Promise(resolve => setTimeout(resolve, 0));
            expect(document.getElementById('redirectDescription').textContent).toContain('Start your free trial to enable');
            expect(document.getElementById('accessLink').textContent).toBe('Start free trial in app');
            expect(document.getElementById('redirectToggle').classList.contains('hidden')).toBe(true);
            expect(toggleButton.checked).toBe(true);
            expect(browser.storage.local.set).not.toHaveBeenCalled();
        });
        it('offers recovery when native access cannot be checked', async () => {
            browser.runtime.sendNativeMessage.mockRejectedValue(new Error('Native unavailable'));
            document.dispatchEvent(new Event('DOMContentLoaded'));
            await new Promise(resolve => setTimeout(resolve, 0));
            expect(document.getElementById('accessTitle').textContent).toBe('Check your access');
        });
        it('should track popup opens', async () => {
            browser.storage.local.get.mockResolvedValue({ enabled: true });
            browser.runtime.sendNativeMessage.mockResolvedValue({});

            document.dispatchEvent(new Event('DOMContentLoaded'));
            await new Promise(resolve => setTimeout(resolve, 0));

            expect(browser.runtime.sendNativeMessage).toHaveBeenCalledWith(
                {
                    type: 'trackEvent',
                    event: 'extension_popup_opened',
                    properties: {
                        surface: 'extension_popup'
                    }
                }
            );
        });

        it('should load initial state from storage', async () => {
            browser.storage.local.get.mockResolvedValue({ enabled: true });
            browser.runtime.sendNativeMessage.mockResolvedValue({
                reviewURL: 'https://apps.apple.com/app/id6740840706?action=write-review',
                canTip: true,
                supportURL: 'braversearch://support'
            });
            
            // Trigger DOMContentLoaded
            document.dispatchEvent(new Event('DOMContentLoaded'));
            
            // Wait for async operations
            await new Promise(resolve => setTimeout(resolve, 0));
            
            expect(toggleButton.checked).toBe(true);
            expect(reviewLink.href).toBe('https://apps.apple.com/app/id6740840706?action=write-review');
            expect(supportCard.classList.contains('hidden')).toBe(false);
            expect(supportLink.href).toBe('braversearch://support');
            expect(supportLink.classList.contains('hidden')).toBe(false);
            expect(supportLink.textContent).toContain('Give Thanks!');
        });
        
        it('should handle disabled initial state', async () => {
            browser.storage.local.get.mockResolvedValue({ enabled: false });
            browser.runtime.sendNativeMessage.mockResolvedValue({
                reviewURL: 'https://apps.apple.com/app/id6740840706?action=write-review',
                canTip: false
            });
            
            document.dispatchEvent(new Event('DOMContentLoaded'));
            await new Promise(resolve => setTimeout(resolve, 0));
            
            expect(toggleButton.checked).toBe(false);
            expect(supportCard.classList.contains('hidden')).toBe(true);
            expect(supportLink.classList.contains('hidden')).toBe(true);
        });
    });
    
    describe('Toggle functionality', () => {
        beforeEach(async () => {
            browser.storage.local.get.mockResolvedValue({ enabled: false });
            browser.runtime.sendNativeMessage.mockResolvedValue({
                reviewURL: 'https://apps.apple.com/app/id6740840706?action=write-review',
                canTip: false
            });
            document.dispatchEvent(new Event('DOMContentLoaded'));
            await new Promise(resolve => setTimeout(resolve, 0));
            browser.runtime.sendNativeMessage.mockClear();
        });
        
        it('should update storage and UI when toggled on', async () => {
            browser.storage.local.set.mockResolvedValue(undefined);
            
            toggleButton.checked = true;
            toggleButton.dispatchEvent(new Event('change'));
            
            await new Promise(resolve => setTimeout(resolve, 0));
            
            expect(browser.storage.local.set).toHaveBeenCalledWith({ enabled: true });
            expect(toggleButton.checked).toBe(true);
            expect(browser.runtime.sendNativeMessage).not.toHaveBeenCalled();
        });

        it('should handle storage errors', async () => {
            browser.storage.local.set.mockRejectedValue(new Error('Storage error'));
            
            toggleButton.checked = true;
            toggleButton.dispatchEvent(new Event('change'));
            
            await new Promise(resolve => setTimeout(resolve, 0));
            
            expect(toggleButton.checked).toBe(false);
            expect(browser.runtime.sendNativeMessage).not.toHaveBeenCalled();
        });
    });
});
