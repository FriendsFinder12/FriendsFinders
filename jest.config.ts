import { realpathSync } from 'fs';
import { join } from 'path';
import type { Config } from 'jest';

// Jest matches this key against the canonical path of every source file. On Windows the case of
// the drive letter depends on the shell (c:\ or C:\), so resolve the real path instead of
// writing './src/utils/', which would then report that it found no coverage data.
const utilsPath = realpathSync.native(join(__dirname, 'src', 'utils'));

const config: Config = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  // src must be a root too, otherwise untested source files are left out of coverage reports.
  roots: ['<rootDir>/src', '<rootDir>/tests'],
  testMatch: ['<rootDir>/tests/**/*.test.ts'],
  collectCoverageFrom: ['src/**/*.ts'],
  // Checked when the tests run with --coverage (npm run test:coverage, which CI uses). The
  // utilities hold the logic, so they must stay better covered than the handlers around them.
  // Jest leaves the files of a path rule out of 'global', so 'global' judges the rest: the handlers.
  coverageThreshold: {
    global: { statements: 70, branches: 70, functions: 70, lines: 70 },
    [utilsPath]: { statements: 80, branches: 80, functions: 80, lines: 80 },
  },
  clearMocks: true,
};

export default config;
