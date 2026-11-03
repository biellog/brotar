// E2E do modo conta: app compilado com Supabase "fake" (rotas interceptadas → Postgres local real).
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: 'tests/e2e-supabase',
  timeout: 30_000,
  workers: 1,
  reporter: [['list']],
  use: { baseURL: 'http://localhost:4174/', ...devices['Pixel 7'] },
  webServer: {
    command: 'npx vite build --outDir dist-sb && npx vite preview --outDir dist-sb --port 4174 --strictPort',
    url: 'http://localhost:4174/',
    reuseExistingServer: false,
    timeout: 60_000,
    env: { VITE_SUPABASE_URL: 'https://fake-proj.supabase.co', VITE_SUPABASE_ANON_KEY: 'anon-key-for-tests-0123456789' },
  },
});
