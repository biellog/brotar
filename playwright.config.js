import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: 'tests/e2e',
  timeout: 30_000,
  fullyParallel: true,
  reporter: [['list']],
  use: { baseURL: 'http://localhost:4173/', ...devices['Pixel 7'] },
  webServer: { command: 'npm run preview', url: 'http://localhost:4173/', reuseExistingServer: true, timeout: 30_000 },
});
