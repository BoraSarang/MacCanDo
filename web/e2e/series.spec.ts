// [FEATURE] E2E — 시리즈/카테고리/헬스 (TC-E2E-WEB-003)
import { test, expect } from "@playwright/test";

test.describe("시리즈", () => {
  test("허브: 카드 5개 (커버 + N개의 글)", async ({ page }) => {
    await page.goto("/series");
    await expect(page.getByRole("heading", { name: /📚 시리즈/ })).toBeVisible();
    const cards = page.locator("main a[href^='/series/']");
    await expect(cards).toHaveCount(5);
    await expect(cards.first().getByText(/개의 글/)).toBeVisible();
  });

  test("카드 → 상세: 1~N편 순서 노출", async ({ page }) => {
    await page.goto("/series");
    const series = page.getByRole("heading", { name: "맥을 처음 접할 때 필요한 필수 앱" });
    await series.click();
    await expect(page).toHaveURL(/\/series\//);
    const links = page.locator("ol a[href^='/post/']");
    await expect(links).toHaveCount(4);
    await expect(links.nth(0)).toContainText("맥 첫 시작");
    await expect(links.nth(1)).toContainText("Homebrew");
    await expect(links.nth(2)).toContainText("CleanMyMac X");
    await expect(links.nth(3)).toContainText("TetherLens");
  });

  test("상세: 커버 이미지 + 취지 소개 노출", async ({ page }) => {
    await page.goto("/series");
    await page.getByRole("heading", { name: "맥 파일 관리" }).click();
    await expect(page.locator("header img[src='/series/files.svg']")).toBeVisible();
    await expect(page.getByText("이런 분에게 추천")).toBeVisible();
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