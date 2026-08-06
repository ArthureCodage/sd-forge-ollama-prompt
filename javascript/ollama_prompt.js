(function () {
    "use strict";

    function waitForElement(selector, callback) {
        const el = document.querySelector(selector);
        if (el) {
            callback(el);
        } else {
            const observer = new MutationObserver((mutations, obs) => {
                const el = document.querySelector(selector);
                if (el) {
                    obs.disconnect();
                    callback(el);
                }
            });
            observer.observe(document.body, { childList: true, subtree: true });
        }
    }

    function sendToPromptField(tab, text) {
        if (!text) return;

        const tabId = tab === "txt2img" ? "txt2img" : "img2img";

        const selectTab = () => {
            const tabBtn = document.querySelector(
                `#tabs > .tab-nav > button[data-testid="${tabId}"]`
            );
            if (tabBtn) {
                tabBtn.click();
                return true;
            }
            const altBtn = document.querySelector(
                `button#${tabId}_tab, [data-testid="${tabId}_tab"]`
            );
            if (altBtn) {
                altBtn.click();
                return true;
            }
            return false;
        };

        const fillPrompt = () => {
            const textareas = document.querySelectorAll(
                `#${tabId}_prompt textarea, #${tabId} textarea[label="Prompt"]`
            );
            if (textareas.length > 0) {
                const textarea = textareas[0];
                const nativeInputValueSetter = Object.getOwnPropertyDescriptor(
                    window.HTMLTextAreaElement.prototype,
                    "value"
                ).set;
                nativeInputValueSetter.call(textarea, text);
                textarea.dispatchEvent(new Event("input", { bubbles: true }));
                textarea.dispatchEvent(new Event("change", { bubbles: true }));
                return true;
            }
            return false;
        };

        if (selectTab()) {
            setTimeout(fillPrompt, 500);
        }
    }

    document.addEventListener("DOMContentLoaded", () => {
        const observer = new MutationObserver(() => {
            document
                .querySelectorAll('[id*="ollama"] button')
                .forEach((btn) => {
                    if (btn.dataset.ollamaHooked) return;
                    btn.dataset.ollamaHooked = "true";
                });
        });

        observer.observe(document.body, { childList: true, subtree: true });
    });
})();
