// Import jest-webextension-mock first
require('jest-webextension-mock');

// Clear all mocks before each test
beforeEach(() => {
    jest.clearAllMocks();
});

// Mock browser.storage API
global.browser = {
    runtime: {
        onMessage: { addListener: jest.fn() },
        sendMessage: jest.fn(() => Promise.resolve({ ok: true })),
        sendNativeMessage: jest.fn(() => Promise.resolve({ analytics: { durablyQueued: true } }))
    },
    storage: {
        onChanged: {
            addListener: jest.fn(),
            removeListener: jest.fn(),
            hasListener: jest.fn()
        },
        local: {
            get: jest.fn(() => Promise.resolve({})),
            set: jest.fn(() => Promise.resolve())
        }
    },
    tabs: {
        get: jest.fn(() => Promise.resolve({})),
        onRemoved: { addListener: jest.fn() },
        update: jest.fn(() => Promise.resolve({}))
    },
    webNavigation: {
        onCompleted: { addListener: jest.fn() },
        onBeforeNavigate: {
            addListener: jest.fn(),
            removeListener: jest.fn(),
            hasListener: jest.fn()
        }
    }
};

// Mock console methods
global.console = {
    ...console,
    log: jest.fn(),
    error: jest.fn()
}; 
