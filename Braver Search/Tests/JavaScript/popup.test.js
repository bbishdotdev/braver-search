/**
 * @jest-environment jsdom
 */

describe('Popup Script', () => {
    let toggleButton;
    let statusDot;
    let statusText;
    let reviewLink;
    let supportCard;
    let supportLink;
    
    beforeEach(() => {
        // Set up our document body
        document.body.innerHTML = `
            <input type="checkbox" id="toggleButton">
            <div class="status-dot"></div>
            <div class="status-text"></div>
            <a id="reviewLink" href="#"></a>
            <section id="supportCard" class="hidden"></section>
            <a id="supportLink" href="#" class="hidden"></a>
        `;
        
        toggleButton = document.getElementById('toggleButton');
        statusDot = document.querySelector('.status-dot');
        statusText = document.querySelector('.status-text');
        reviewLink = document.getElementById('reviewLink');
        supportCard = document.getElementById('supportCard');
        supportLink = document.getElementById('supportLink');
        
        // Clear all mocks
        jest.clearAllMocks();
        
        // Import the popup script
        require('../../Shared (Extension)/Resources/popup.js');
    });
    
    describe('Initial state', () => {
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
            expect(statusDot.classList.contains('active')).toBe(true);
            expect(statusText.classList.contains('active')).toBe(true);
            expect(statusText.textContent).toBe('Enabled');
            expect(reviewLink.href).toBe('https://apps.apple.com/app/id6740840706?action=write-review');
            expect(supportCard.classList.contains('hidden')).toBe(false);
            expect(supportLink.href).toBe('braversearch://support');
            expect(supportLink.classList.contains('hidden')).toBe(false);
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
            expect(statusDot.classList.contains('active')).toBe(false);
            expect(statusText.classList.contains('active')).toBe(false);
            expect(statusText.textContent).toBe('Disabled');
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
            expect(statusDot.classList.contains('active')).toBe(true);
            expect(statusText.textContent).toBe('Enabled');
            expect(browser.runtime.sendNativeMessage).not.toHaveBeenCalled();
        });

        it('should handle storage errors', async () => {
            browser.storage.local.set.mockRejectedValue(new Error('Storage error'));
            
            toggleButton.checked = true;
            toggleButton.dispatchEvent(new Event('change'));
            
            await new Promise(resolve => setTimeout(resolve, 0));
            
            expect(toggleButton.checked).toBe(false);
            expect(statusText.textContent).toBe('Disabled');
            expect(browser.runtime.sendNativeMessage).not.toHaveBeenCalled();
        });
    });
});
