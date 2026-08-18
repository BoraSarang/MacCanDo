// [E2E] Playwright 설정 — 시스템 Chrome 사용 (다운로드 회피, 표준 7.7)
// 로컬: 기존 dev 서버(3000) 재사용. CI: next start 기반 빌드 서버 기동
import { defineConfig } from "@playwright/test";

const CI = !!process.env.CI;

export default defineConfig({
  testDir: "./tests/e2e",
  timeout: 30_000,
  retries: CI ? 2 : 0,
  reporter: CI ? [["list"], ["html", { open: "never" }]] : [["list"]],
  use: {
    baseURL: "http://localhost:3000",
    trace: "retain-on-failure",
  },
  projects: [{ name: "desktop-chrome", use: { browserName: "chromium", channel: "chrome" } }],
  webServer: CI
    ? {
        command: "npm run build && npm run start",
        url: "http://localhost:3000",
        reuseExistingServer: false,
        timeout: 180_000,
      }
    : {
        command: "npm run dev",
        url: "http://localhost:3000",
        reuseExistingServer: true,
        timeout: 60_000,
      },
});