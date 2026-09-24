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
        postMessage = jest.fn();
        context = vm.createContext({ document, webkit: { messageHandlers: { controller: { postMessage } } } });
        vm.runInContext(source, context);
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
