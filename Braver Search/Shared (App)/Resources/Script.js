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
    const reviewButton = document.querySelector(".review-button");
    const reviewIcon = document.querySelector(".review-icon");

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
