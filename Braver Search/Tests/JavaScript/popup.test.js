/**
 * @jest-environment jsdom
 */

describe('Popup Script', () => {
    let toggleButton;
    let statusDot;
    let statusText;
    
    beforeEach(() => {
        // Set up our document body
        document.body.innerHTML = `
            <input type="checkbox" id="toggleButton">
            <div class="status-dot"></div>
            <div class="status-text"></div>
        `;
        
        toggleButton = document.getElementById('toggleButton');
        statusDot = document.querySelector('.status-dot');
        statusText = document.querySelector('.status-text');
        
        // Clear all mocks
        jest.clearAllMocks();
        
        // Import the popup script
        require('../../Shared (Extension)/Resources/popup.js');
    });
    
    describe('Initial state', () => {
        it('should load initial state from storage', async () => {
            browser.storage.local.get.mockResolvedValue({ enabled: true });
            
            // Trigger DOMContentLoaded
            document.dispatchEvent(new Event('DOMContentLoaded'));
            
            // Wait for async operations
            await new Promise(resolve => setTimeout(resolve, 0));
            
            expect(toggleButton.checked).toBe(true);
            expect(statusDot.classList.contains('active')).toBe(true);
            expect(statusText.classList.contains('active')).toBe(true);
            expect(statusText.textContent).toBe('Enabled');
        });
        
        it('should handle disabled initial state', async () => {
            browser.storage.local.get.mockResolvedValue({ enabled: false });
            
            document.dispatchEvent(new Event('DOMContentLoaded'));
            await new Promise(resolve => setTimeout(resolve, 0));
            
            expect(toggleButton.checked).toBe(false);
            expect(statusDot.classList.contains('active')).toBe(false);
            expect(statusText.classList.contains('active')).toBe(false);
            expect(statusText.textContent).toBe('Disabled');
        });
    });
    
    describe('Toggle functionality', () => {
        beforeEach(async () => {
            browser.storage.local.get.mockResolvedValue({ enabled: false });
            document.dispatchEvent(new Event('DOMContentLoaded'));
            await new Promise(resolve => setTimeout(resolve, 0));
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
