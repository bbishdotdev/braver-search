let setupAccess = { allowed: false, state: "unknown" };
let lastSetupSnapshot = { status: "idle" };

function show(platform, enabled, useSettingsInsteadOfPreferences) {
    document.body.classList.add(`platform-${platform}`);

    if (useSettingsInsteadOfPreferences) {
        document.getElementsByClassName('platform-mac state-on')[0].innerText = "Braver Search’s extension is currently on. You can turn it off in the Extensions section of Safari Settings.";
        document.getElementsByClassName('platform-mac state-off')[0].innerText = "Braver Search’s extension is currently off. You can turn it on in the Extensions section of Safari Settings.";
        document.getElementsByClassName('platform-mac state-unknown')[0].innerText = "You can turn on Braver Search’s extension in the Extensions section of Safari Settings.";
        document.getElementsByClassName('platform-mac open-preferences')[0].innerText = "Quit and Open Safari Settings…";
    }

    if (typeof enabled === "boolean") {
        document.body.classList.toggle(`state-on`, enabled);
        document.body.classList.toggle(`state-off`, !enabled);
    } else {
        document.body.classList.remove(`state-on`);
        document.body.classList.remove(`state-off`);
    }
}

function openPreferences() {
    webkit.messageHandlers.controller.postMessage("open-preferences");
}

function updateMonetization(payload) {
    const verification = document.getElementById("access-verification");
    const verifying = payload.isVerifyingAccess === true;
    const verificationMessage = payload.accessVerificationMessage || "";
    verification.classList.toggle("hidden", payload.accessAllowed === true || (!verifying && !verificationMessage));
    document.getElementById("access-verification-title").textContent = verifying
        ? "Checking App Store access…" : "Check your App Store access";
    document.getElementById("access-verification-message").textContent = verifying
        ? "Checking your saved trial and lifetime access with Apple." : verificationMessage;
    const retry = document.getElementById("retry-access");
    retry.disabled = verifying;
    retry.textContent = verifying ? "Checking…" : "Retry verification";
    retry.onclick = () => webkit.messageHandlers.controller.postMessage({ action: "retry-access" });
    setupAccess = { allowed: payload.accessAllowed === true, state: payload.accessState };
    const controls = document.getElementById("setup-test-controls");
    const destination = document.getElementById(setupAccess.allowed ? "setup-test-primary" : "setup-help");
    if (controls.parentElement !== destination) {
        if (setupAccess.allowed) { destination.appendChild(controls); }
        else { document.getElementById("setup-access-explanation").after(controls); }
    }
    document.getElementById("setup-test-primary").classList.toggle("hidden", !setupAccess.allowed);
    document.getElementById("setup-access-explanation").classList.toggle("hidden", setupAccess.allowed);
    document.getElementById("setup-test-label").textContent = setupAccess.allowed ? "Test my setup" : "Check extension setup";
    updateSetup(lastSetupSnapshot);
    const access = document.getElementById("access-summary");
    if (access) {
        access.classList.toggle("hidden", payload.accessState === "free");
        const expired = payload.accessState === "expired";
        const eligible = payload.accessState === "eligible";
        access.classList.toggle("access-expired", expired);
        access.classList.toggle("access-needs-action", expired || eligible);
        document.getElementById("access-summary-badge").classList.toggle("hidden", !expired);
        document.getElementById("access-summary-title").textContent = expired
            ? "Safari redirects are paused" : eligible ? "Start your free trial to enable Safari redirects" : payload.accessTitle;
        document.getElementById("access-summary-message").textContent = expired
            ? "Your trial has ended. Pay once to turn redirects back on."
            : eligible ? "Try it for 14 days. No automatic charge." : payload.accessMessage;
        document.getElementById("access-summary-action").textContent = eligible ? "Start free trial"
            : expired ? "Unlock lifetime access" : payload.accessState === "trial" ? "See lifetime prices"
            : payload.accessState === "unknown" ? "Check my access" : "View access";
        access.onclick = () => webkit.messageHandlers.controller.postMessage({ action: "open-lifetime" });
    }
    const supportSection = document.querySelector(".support-section");
    const supportProducts = document.querySelector(".support-products");
    const reviewButton = document.querySelector(".review-card .review-button");
    const reviewIcon = document.querySelector(".review-icon");

    if (reviewButton) {
        reviewButton.onclick = () => webkit.messageHandlers.controller.postMessage({ action: "open-review" });
    }

    if (!supportSection || !supportProducts || !reviewButton) {
        return;
    }

    if (reviewIcon && payload.reviewImageDataURL) {
        reviewIcon.src = payload.reviewImageDataURL;
    }

    supportSection.classList.toggle("hidden", !payload.canTip);
    supportProducts.innerHTML = "";

    if (!payload.canTip) {
        return;
    }

    payload.products.forEach((product) => {
        const card = document.createElement("article");
        card.className = "support-product";
        const imageMarkup = product.imageDataURL
            ? `<img class="support-product-art" src="${product.imageDataURL}" alt="${product.displayName}">`
            : "";
        card.innerHTML = `
            <span class="support-product-title">${product.displayName}</span>
            ${imageMarkup}
            <span class="support-product-description">${product.description ?? ""}</span>
            <button type="button" class="support-product-button">Tip ${product.price}</button>
        `;
        card.querySelector(".support-product-button")?.addEventListener("click", () => {
            webkit.messageHandlers.controller.postMessage({
                action: "purchase",
                productId: product.id
            });
        });
        supportProducts.appendChild(card);
    });

}

function focusSupportSection() {
    const supportSection = document.querySelector(".support-section");
    if (!supportSection || supportSection.classList.contains("hidden")) {
        return;
    }

    supportSection.scrollIntoView({ behavior: "smooth", block: "center" });
}

document.querySelector("button.open-preferences").addEventListener("click", openPreferences);
document.getElementById("privacy-policy")?.addEventListener("click", event => {
    event.preventDefault();
    webkit.messageHandlers.controller.postMessage({ action: "open-privacy" });
});

function updateSetup(payload) {
    lastSetupSnapshot = payload;
    const result = document.getElementById('setup-result');
    if (payload.status === 'success' && !setupAccess.allowed) {
        const nextStep = setupAccess.state === 'eligible'
            ? 'Start your trial or unlock lifetime access to enable searches.'
            : setupAccess.state === 'expired'
                ? 'Your trial has ended. Unlock lifetime access to enable searches.'
                : 'Check your access in the app to enable searches.';
        result.textContent = `Extension setup verified. ${nextStep}`;
    } else {
        result.textContent = [payload.title, payload.message].filter(Boolean).join('. ');
    }
    result.classList.toggle('hidden', payload.status === 'idle');
}
document.getElementById('test-setup').addEventListener('click', () => {
    webkit.messageHandlers.controller.postMessage({ action: 'test-setup' });
});
document.getElementById('setup-help').addEventListener('toggle', event => {
    if (event.target.open) { webkit.messageHandlers.controller.postMessage({ action: 'setup-help' }); }
});
