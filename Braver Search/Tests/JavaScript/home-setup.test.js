/** @jest-environment jsdom */
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const root = path.join(__dirname, '../../Shared (App)/Resources');
const html = fs.readFileSync(path.join(root, 'Base.lproj/Main.html'), 'utf8');
const source = fs.readFileSync(path.join(root, 'Script.js'), 'utf8');

describe('Mac home setup access presentation', () => {
    let context;
    let postMessage;
    const payload = (state, allowed) => ({ accessState: state, accessAllowed: allowed, accessTitle: 'Access', accessMessage: 'Details', canTip: false });
    beforeEach(() => {
        document.documentElement.innerHTML = html;
        const style = document.createElement('style');
        style.textContent = fs.readFileSync(path.join(root, 'Style.css'), 'utf8');
        document.head.appendChild(style);
        postMessage = jest.fn();
        context = vm.createContext({ document, webkit: { messageHandlers: { controller: { postMessage } } } });
        vm.runInContext(source, context);
    });
    it('shows a clear trial action, then updates the action after activation and expiry', () => {
        const button = document.getElementById('access-summary');
        const action = document.getElementById('access-summary-action');
        context.updateMonetization(payload('eligible', false));
        expect(button.textContent).toContain('Start your free trial to enable Safari redirects');
        expect(action.textContent).toBe('Start free trial');
        expect(getComputedStyle(document.getElementById('access-summary-badge')).display).toBe('none');
        button.click();
        expect(postMessage).toHaveBeenCalledWith({ action: 'open-lifetime' });
        context.updateMonetization(payload('trial', true));
        expect(action.textContent).toBe('See lifetime prices');
        context.updateMonetization(payload('expired', false));
        expect(button.textContent).toContain('Safari redirects are paused');
        expect(getComputedStyle(document.getElementById('access-summary-badge')).display).not.toBe('none');
        expect(action.textContent).toBe('Unlock lifetime access');
        context.updateMonetization(payload('lifetime', true));
        expect(action.textContent).toBe('View access');
        expect(button.classList.contains('access-expired')).toBe(false);
    });
    it('actually hides the donation section for paying cohorts and keeps review usable', () => {
        const support = document.querySelector('.support-section');
        for (const state of ['eligible', 'trial', 'expired', 'lifetime']) {
            context.updateMonetization(payload(state, false));
            expect(getComputedStyle(support).display).toBe('none');
        }
        document.querySelector('.review-card .review-button').click();
        expect(postMessage).toHaveBeenCalledWith({ action: 'open-review' });
        context.updateMonetization({ ...payload('grandfathered', true), canTip: true, products: [] });
        expect(getComputedStyle(support).display).toBe('flex');
        context.updateMonetization(payload('free', true));
        expect(getComputedStyle(document.getElementById('access-summary')).display).toBe('none');
    });
    it.each(['eligible', 'expired', 'unknown'])('keeps the diagnostic under help for %s users', state => {
        context.updateMonetization(payload(state, false));
        expect(document.getElementById('setup-test-controls').parentElement.id).toBe('setup-help');
        expect(document.getElementById('setup-help').open).toBe(false);
        expect(document.getElementById('setup-test-label').textContent).toBe('Check extension setup');
        document.getElementById('test-setup').click();
        expect(postMessage).toHaveBeenCalledWith({ action: 'test-setup' });
    });
    it.each(['trial', 'lifetime', 'grandfathered', 'free'])('keeps the primary setup action for %s users', state => {
        context.updateMonetization(payload(state, true));
        expect(document.getElementById('setup-test-controls').parentElement.id).toBe('setup-test-primary');
        expect(document.getElementById('setup-test-label').textContent).toBe('Test my setup');
    });
    it('relabels an existing successful result as access expires and restores it after purchase', () => {
        context.updateSetup({ status: 'success', title: 'Setup verified', message: 'Test search completed' });
        context.updateMonetization(payload('eligible', false));
        const result = document.getElementById('setup-result');
        expect(result.textContent).toContain('Start your trial or unlock lifetime access');
        context.updateMonetization(payload('trial', true));
        expect(result.textContent).toBe('Setup verified. Test search completed');
        context.updateMonetization(payload('expired', false));
        expect(result.textContent).toContain('Your trial has ended. Unlock lifetime access');
        expect(document.getElementById('setup-test-controls').parentElement.id).toBe('setup-help');
        context.updateMonetization(payload('lifetime', true));
        expect(result.textContent).toBe('Setup verified. Test search completed');
        document.getElementById('test-setup').click();
        expect(postMessage).toHaveBeenCalledTimes(1);
    });
    it('preserves diagnostic failures rather than showing a success or purchase message', () => {
        context.updateMonetization(payload('expired', false));
        context.updateSetup({ status: 'inconclusive', title: 'Test incomplete', message: 'Check Safari permissions' });
        expect(document.getElementById('setup-result').textContent).toBe('Test incomplete. Check Safari permissions');
    });
    it('exposes verification failure and an explicit retry even when the access policy remains free', () => {
        context.updateMonetization({ ...payload('free', true), accessVerificationMessage: 'Apple verification failed (StoreKit 2)' });
        expect(document.getElementById('access-verification').classList.contains('hidden')).toBe(false);
        expect(document.getElementById('access-verification-message').textContent).toContain('StoreKit 2');
        document.getElementById('retry-access').click();
        expect(postMessage).toHaveBeenCalledWith({ action: 'retry-access' });
        context.updateMonetization({ ...payload('free', true), isVerifyingAccess: true });
        expect(document.getElementById('retry-access').disabled).toBe(true);
        document.getElementById('retry-access').click();
        expect(postMessage).toHaveBeenCalledTimes(1);
        context.updateMonetization(payload('eligible', false));
        expect(document.getElementById('access-verification').classList.contains('hidden')).toBe(true);
        expect(document.getElementById('access-summary').classList.contains('hidden')).toBe(false);
        expect(document.querySelector('.support-section').classList.contains('hidden')).toBe(true);
    });
});
