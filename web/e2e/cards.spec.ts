// [FEATURE] 목록 카드 개선 + 환영 배너 E2E — T-18 (iosgods 패턴)
// TC-T18-001: 홈 카드 — 태그 배지 + 상대시간
// TC-T18-002: 글 상세 — 비로그인 환영 배너 표시
// TC-T18-003: 정적 페이지 — 배너 미표시
import { test, expect } from "@playwright/test";

test.describe("T-18 목록 카드 개선 + 환영 배너", () => {
  test("TC-T18-001: 홈 카드 태그 배지 + 상대시간 표시", async ({ page }) => {
    await page.goto("/");
    // 태그 배지 (#태그, 카드 안)
    const tagBadge = page.locator("a.card .badge.bg-surface-hover").first();
    await expect(tagBadge).toBeVisible();
    await expect(tagBadge).toHaveText(/#.+/);
    // 상대시간 (방금 전 / N분 전 / N시간 전 / N일 전)
    await expect(page.locator("a.card span[title]").first()).toContainText(/(방금 전|\d+분 전|\d+시간 전|\d+일 전)/);
  });

  test("TC-T18-002: 글 상세 — 비로그인 환영 배너 표시", async ({ page }) => {
    await page.goto("/post/iterm2-tmux-oh-my-zsh");
    const banner = page.getByRole("note");
    await expect(banner).toBeVisible();
    await expect(banner).toContainText("안녕하세요!");
    await expect(banner).toContainText("다운로드 링크가 공개");
    await expect(banner.getByRole("button", { name: "로그인하고 시작하기" })).toBeVisible();
  });

  test("TC-T18-003: 정적 페이지 — 환영 배너 미표시", async ({ page }) => {
    await page.goto("/post/about");
    await expect(page.getByRole("note")).toHaveCount(0);
  });
});
