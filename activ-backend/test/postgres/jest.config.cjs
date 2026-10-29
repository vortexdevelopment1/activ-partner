module.exports = {
  rootDir: '../..',
  testRegex: 'test/postgres/.*\\.integration\\.spec\\.ts$',
  transform: { '^.+\\.ts$': ['ts-jest', { tsconfig: 'tsconfig.json' }] },
  testEnvironment: 'node',
  setupFilesAfterEnv: ['<rootDir>/test/no-network.cjs'],
  testTimeout: 60000,
};
