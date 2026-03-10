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
    const supportSection = document.querySelector(".support-section");
    const supportProducts = document.querySelector(".support-products");
    const supportThanks = document.querySelector(".support-thanks");
    const reviewButton = document.querySelector(".review-button");

    if (!supportSection || !supportProducts || !supportThanks || !reviewButton) {
        return;
    }

    supportSection.classList.toggle("hidden", !payload.canTip);
    supportThanks.classList.toggle("hidden", !payload.hasDonated);
    supportProducts.innerHTML = "";

    if (!payload.canTip) {
        return;
    }

    payload.products.forEach((product) => {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "support-product";
        button.innerHTML = `<span class="support-product-title">${product.displayName}</span><span class="support-product-price">${product.price}</span>`;
        button.addEventListener("click", () => {
            webkit.messageHandlers.controller.postMessage({
                action: "purchase",
                productId: product.id
            });
        });
        supportProducts.appendChild(button);
    });

    reviewButton.onclick = () => {
        webkit.messageHandlers.controller.postMessage({ action: "open-review" });
    };
}

function focusSupportSection() {
    const supportSection = document.querySelector(".support-section");
    if (!supportSection || supportSection.classList.contains("hidden")) {
        return;
    }

    supportSection.scrollIntoView({ behavior: "smooth", block: "center" });
}

document.querySelector("button.open-preferences").addEventListener("click", openPreferences);
