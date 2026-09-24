console.log("Braver Search: Script loaded");

document.addEventListener('DOMContentLoaded', async function() {
    console.log("Braver Search: DOM loaded");
    
    const toggleButton = document.getElementById('toggleButton');
    const reviewLink = document.getElementById('reviewLink');
    const supportCard = document.getElementById('supportCard');
    const supportLink = document.getElementById('supportLink');

    console.log("Braver Search: Elements found?", {
        button: !!toggleButton
    });

    if (!toggleButton) {
        console.error("Braver Search: Toggle button not found!");
        return;
    }

    function trackEvent(event, properties = {}) {
        if (!browser.runtime?.sendNativeMessage) {
            return;
        }

        browser.runtime.sendNativeMessage({
            type: 'trackEvent',
            event,
            properties
        }).catch(error => {
            console.error("Braver Search: Analytics event failed", error);
        });
    }

    async function loadMonetizationState() {
        if (!browser.runtime?.sendNativeMessage) {
            return;
        }

        try {
            const response = await browser.runtime.sendNativeMessage({
                type: 'getMonetizationState'
            });

            showAccessState(response);
            if (reviewLink && response?.reviewURL) {
                reviewLink.href = response.reviewURL;
            }

            if (supportCard && supportLink && response?.canTip && response?.supportURL) {
                supportCard.classList.remove('hidden');
                supportLink.href = response.supportURL;
                supportLink.classList.remove('hidden');
            }
        } catch (error) {
            console.error("Braver Search: Failed to load monetization state", error);
            showAccessState({ accessAllowed: false, userState: 'unknown' });
        }
    }

    function showAccessState(response) {
        const blocked = response?.accessAllowed === false;
        document.getElementById('redirectToggle').classList.toggle('hidden', blocked);
        document.getElementById('accessCard').classList.toggle('hidden', !blocked);
        // Preserve the saved switch preference. Access, not a switch change, pauses redirects.
        document.getElementById('redirectTitle').textContent = blocked ? 'Redirects paused' : 'Redirect Search';
        const description = document.getElementById('redirectDescription');
        if (!blocked) {
            description.textContent = 'Redirect Safari searches to Brave Search.';
            return;
        }
        const title = document.getElementById('accessTitle');
        const message = document.getElementById('accessMessage');
        const link = document.getElementById('accessLink');
        if (response.userState === 'eligible') {
            description.textContent = 'Start your free trial to enable Safari search redirects.';
            title.textContent = 'Try it free for 14 days';
            message.textContent = 'No automatic charge. Buy once to continue after your trial.';
            link.textContent = 'Start free trial in app';
        } else if (response.userState === 'expired') {
            description.textContent = 'Your free trial has ended. Unlock lifetime access to resume redirects.';
            title.textContent = 'Choose your lifetime price';
            message.textContent = 'Every price unlocks the full app. One purchase, no subscription.';
            link.textContent = 'See lifetime prices';
        } else {
            description.textContent = 'Open the app to check your access before redirecting searches.';
            title.textContent = 'Check your access';
            message.textContent = 'Restore an existing purchase or check your trial eligibility in the app.';
            link.textContent = 'Open Braver Search';
        }
    }

    // Function to get current state
    async function getCurrentState() {
        try {
            const result = await browser.storage.local.get('enabled');
            console.log("Braver Search: Got state", result);
            return result.enabled || false;
        } catch (error) {
            console.error("Braver Search: Failed to get state", error);
            return false;
        }
    }

    // Function to set state
    async function setState(enabled) {
        try {
            console.log("Braver Search: Setting state to", enabled);
            await browser.storage.local.set({ enabled });
            return enabled;
        } catch (error) {
            console.error("Braver Search: Failed to set state", error);
            return null;
        }
    }

    // Load initial state
    console.log("Braver Search: Loading initial state");
    trackEvent('extension_popup_opened', {
        surface: 'extension_popup'
    });
    const initialState = await getCurrentState();
    console.log("Braver Search: Initial state", initialState);
    updateUI(initialState);
    await loadMonetizationState();

    // Handle toggle change
    toggleButton.addEventListener('change', async function(event) {
        console.log("Braver Search: Toggle changed");
        
        try {
            const newState = event.target.checked;
            console.log("Braver Search: Setting new state to", newState);
            
            const result = await setState(newState);
            console.log("Braver Search: Set state result", result);
            
            if (result !== null) {
                console.log("Braver Search: State updated successfully");
                updateUI(result);
                console.log("Braver Search: Analytics for toggle will be handled by background storage listener");
            } else {
                console.error("Braver Search: Failed to update state");
                // Revert checkbox state on failure
                event.target.checked = !newState;
            }
        } catch (error) {
            console.error("Braver Search: Toggle failed", error);
            // Revert checkbox state on error
            event.target.checked = !event.target.checked;
        }
    });

    function updateUI(enabled) {
        console.log("Braver Search: Updating UI with state", enabled);
        
        // Update checkbox state
        toggleButton.checked = enabled;
        
        console.log("Braver Search: UI updated");
    }
}); 
