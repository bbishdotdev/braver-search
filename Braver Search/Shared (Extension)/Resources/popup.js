console.log("Braver Search: Script loaded");

document.addEventListener('DOMContentLoaded', async function() {
    console.log("Braver Search: DOM loaded");
    
    const toggleButton = document.getElementById('toggleButton');
    const statusDot = document.querySelector('.status-dot');
    const statusText = document.querySelector('.status-text');

    console.log("Braver Search: Elements found?", {
        button: !!toggleButton,
        dot: !!statusDot,
        text: !!statusText
    });

    if (!toggleButton) {
        console.error("Braver Search: Toggle button not found!");
        return;
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
    const initialState = await getCurrentState();
    console.log("Braver Search: Initial state", initialState);
    updateUI(initialState);

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

        // Update status with transition
        if (enabled) {
            statusDot.classList.add('active');
            statusText.classList.add('active');
            statusText.textContent = 'Enabled';
        } else {
            statusDot.classList.remove('active');
            statusText.classList.remove('active');
            statusText.textContent = 'Disabled';
        }
        
        console.log("Braver Search: UI updated");
    }
}); 
