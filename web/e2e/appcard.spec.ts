// [FEATURE] E2E — 앱 카드 (T-15, TC-APP-001~004)
import { test, expect } from "@playwright/test";

test.describe("앱 카드", () => {
  test("TC-APP-002: [app] 마커 → 카드 3장 (순서 일치)", async ({ page }) => {
    await page.goto("/post/iterm2-tmux-oh-my-zsh");
    const cards = page.locator(".prose .app-card");
    await expect(cards).toHaveCount(3);
    const names = await cards.locator(".app-name").allTextContents();
    expect(names).toEqual(["iTerm2", "tmux", "Oh My Zsh"]);
    // 카드 위치: 각 섹션 제목 바로 뒤 (본문 순서 유지)
    const firstCardPos = await cards.first().evaluate((el) => el.getBoundingClientRect().top);
    const h2 = page.getByRole("heading", { name: "1. iTerm2 — 터미널의 리미티드 에디션" });
    const h2Pos = await h2.evaluate((el) => el.getBoundingClientRect().top);
    expect(firstCardPos).toBeGreaterThan(h2Pos);
  });

  test("TC-APP-003: 앱 카드 다운로드 — 비로그인에도 공개 (게이트 없음)", async ({ page }) => {
    await page.goto("/post/iterm2-tmux-oh-my-zsh");
    const dl = page.locator(".app-card .app-dl").first();
    await expect(dl).toHaveText("공식 다운로드");
    await expect(dl).toHaveAttribute("href", /\/post\/iterm2-tmux-oh-my-zsh\/download\//);
    const home = page.locator(".app-card .app-home").first();
    await expect(home).toHaveAttribute("href", /iterm2\.com/);
  });

  test("TC-APP-004: 기존 게이트 회귀 — 하단 📥는 비로그인 잠김 유지", async ({ page }) => {
    await page.goto("/post/iterm2-tmux-oh-my-zsh");
    const gate = page.getByText("다운로드 링크를 보려면 Google 로그인 후 댓글을 1개 이상 남겨주세요.");
    await expect(gate).toBeVisible();
    // 게이트 다운로드 링크(앱 카드 아님)는 비공개
    const gateSection = page.locator("section", { hasText: "📥 다운로드" });
    await expect(gateSection.locator("a[href*='/download/']")).toHaveCount(0);
  });
});