// Test for boolean parsing of env vars in configModule

describe('configModule boolean parsing from env', () => {
  let originalEnv;
  let loggerWarn = [];

  beforeAll(() => {
    originalEnv = { ...process.env };
    jest.resetModules();
    // Provide a mock logger module so we can capture warnings deterministically
    jest.doMock('../logger', () => ({
      info: jest.fn(),
      warn: (...args) => loggerWarn.push(args),
      error: jest.fn()
    }));
  });

  afterAll(() => {
    process.env = originalEnv;
    jest.resetModules();
  });

  beforeEach(() => {
    loggerWarn = [];
  });

  const loadConfigModule = () => require('../modules/configModule');

  test.each([
    ['true', true],
    ['True', true],
    ['yes', true],
    ['1', true],
    ['on', true],
    ['false', false],
    ['no', false],
    ['0', false],
    ['off', false]
  ])('env value %s should be parsed as %p', (envVal, expected) => {
    process.env = { ...originalEnv, CHANNEL_AUTO_DOWNLOAD: envVal };
    jest.resetModules();
    const configModule = loadConfigModule();
    const cfg = configModule.getConfig();
    expect(cfg.channelAutoDownload).toBe(expected);
  });

  test('invalid boolean value logs a warning and skips override', () => {
    process.env = { ...originalEnv, CHANNEL_AUTO_DOWNLOAD: 'certainly' };
    jest.resetModules();
    const configModule = loadConfigModule();
    const cfg = configModule.getConfig();
    // Default in config can be false; ensure we didn't set it to true
    expect(cfg.channelAutoDownload).not.toBe(true);
    expect(loggerWarn.length).toBeGreaterThanOrEqual(1);
  });
});
