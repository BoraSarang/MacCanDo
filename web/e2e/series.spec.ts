// [FEATURE] E2E — 시리즈/카테고리/헬스 (TC-E2E-WEB-003)
import { test, expect } from "@playwright/test";

test.describe("시리즈", () => {
  test("모아보기: 1~N편 순서 노출", async ({ page }) => {
    await page.goto("/series");
    await expect(page.getByRole("heading", { name: /📚 시리즈/ })).toBeVisible();
    const series = page.getByRole("heading", { name: "맥 필수 유틸리티 가이드" });
    await series.click();
    await expect(page).toHaveURL(/\/series\//);
    const links = page.locator("ol a[href^='/post/']");
    await expect(links).toHaveCount(3);
    await expect(links.nth(0)).toContainText("Homebrew");
    await expect(links.nth(1)).toContainText("TetherLens");
    await expect(links.nth(2)).toContainText("CleanMyMac X");
  });
});

test.describe("카테고리", () => {
  test("유틸리티 글 목록", async ({ page }) => {
    await page.goto("/category/utilities");
    await expect(page.getByRole("heading", { name: "유틸리티" })).toBeVisible();
    await expect(page.locator("main a[href^='/post/']").first()).toBeVisible();
  });
});

test.describe("헬스", () => {
  test("/health 200", async ({ request }) => {
    const res = await request.get("/api/health");
    expect(res.status()).toBe(200);
  });
});