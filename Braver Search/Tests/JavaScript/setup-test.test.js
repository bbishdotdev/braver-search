const fs = require('fs');
const path = require('path');
const vm = require('vm');

const source = fs.readFileSync(path.join(__dirname, '../../Shared (Extension)/Resources/setup-test.js'), 'utf8');
const manifest = require('../../Shared (Extension)/Resources/manifest.json');
const id = '12345678-1234-1234-1234-123456789abc';

function runPage(url, { readyState = 'interactive', subframe = false } = {}) {
    const listeners = {};
    const pageWindow = {
        location: { href: url },
        addEventListener: jest.fn((event, callback) => { listeners[event] = callback; })
    };
    pageWindow.top = subframe ? {} : pageWindow;
    const pageDocument = { readyState };
    const sendMessage = jest.fn(() => Promise.resolve());
    vm.runInNewContext(source, {
        window: pageWindow, document: pageDocument, URL, console,
        browser: { runtime: { sendMessage } }
    });
    return { listeners, pageDocument, sendMessage };
}

describe('setup page wake-up script', () => {
    it('wakes the background from the tagged Google page without sending the query or URL', () => {
        const { sendMessage } = runPage(`https://www.google.com/search?q=setup&braver_setup=${id}`);
        expect(sendMessage).toHaveBeenCalledTimes(1);
        expect(sendMessage).toHaveBeenCalledWith({ type: 'setupTestPageReady' });
    });

    it.each([
        'https://www.google.com/search?q=ordinary',
        'https://www.google.com/search?q=setup&braver_setup=invalid',
        `https://www.google.com/searching?braver_setup=${id}`,
        `https://example.com/search?braver_setup=${id}`,
        `http://www.google.com/search?braver_setup=${id}`
    ])('does nothing on unrelated page %s', url => {
        expect(runPage(url).sendMessage).not.toHaveBeenCalled();
    });

    it('does nothing in a subframe', () => {
        const { sendMessage } = runPage(`https://www.google.com/search?braver_setup=${id}`, { subframe: true });
        expect(sendMessage).not.toHaveBeenCalled();
    });

    it('waits for Brave to finish loading before reporting completion', () => {
        const { sendMessage, listeners, pageDocument } = runPage(`https://search.brave.com/search?q=setup&braver_setup=${id}`);
        expect(sendMessage).not.toHaveBeenCalled();
        listeners.load();
        expect(sendMessage).not.toHaveBeenCalled();
        pageDocument.readyState = 'complete';
        listeners.load();
        expect(sendMessage).toHaveBeenCalledWith({ type: 'setupTestPageCompleted' });
    });

    it('reports Brave completion if injection happens after load', () => {
        const { sendMessage } = runPage(`https://search.brave.com/search?q=setup&braver_setup=${id}`, { readyState: 'complete' });
        expect(sendMessage).toHaveBeenCalledWith({ type: 'setupTestPageCompleted' });
    });

    it('ships the fallback for the two setup origins and main frames only', () => {
        const declaration = manifest.content_scripts.find(item => item.js.includes('setup-test.js'));
        expect(declaration.matches).toEqual(['https://www.google.com/search*', 'https://search.brave.com/search*']);
        expect(declaration.all_frames).toBe(false);
        expect(declaration.run_at).toBe('document_end');
    });
});
