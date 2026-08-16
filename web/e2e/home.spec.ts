// [FEATURE] E2E — 홈/검색 (TC-E2E-WEB-001)
import { test, expect } from "@playwright/test";

test.describe("홈", () => {
  test("카테고리(글 있는 것만) + 최신 게시글 노출", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByRole("heading", { name: "맥으로 이것도 할 수 있다" })).toBeVisible();
    const categoryLinks = page.locator("main a[href^='/category/']");
    const count = await categoryLinks.count();
    expect(count).toBeGreaterThan(0);
    await expect(page.getByRole("heading", { name: "최신 게시글" })).toBeVisible();
    await expect(page.locator("main a[href^='/post/']").first()).toBeVisible();
  });
});

test.describe("검색", () => {
  test("검색어 입력 → 결과 페이지", async ({ page }) => {
    await page.goto("/");
    await page.getByRole("searchbox", { name: "검색어 입력" }).fill("Homebrew");
    await page.getByRole("button", { name: "검색" }).click();
    await expect(page).toHaveURL(/\/search\?q=/);
    await expect(page.getByText(/Homebrew/).first()).toBeVisible();
  });
});