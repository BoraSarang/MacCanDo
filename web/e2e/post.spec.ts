// [FEATURE] E2E — 글 상세 + 시리즈 (TC-E2E-WEB-002)
import { test, expect } from "@playwright/test";

test.describe("글 상세", () => {
  test("메타 + 본문 + 댓글 영역", async ({ page }) => {
    await page.goto("/post/sample-homebrew-guide");
    await expect(page.getByRole("heading", { name: /Homebrew 설치부터 사용까지/ })).toBeVisible();
    await expect(page.getByRole("heading", { name: /댓글/ })).toBeVisible();
    await expect(page.getByRole("button", { name: "Google 로그인" })).toBeVisible();
  });

  test("시리즈 목록: 현재 글 강조 + 다른 편 링크", async ({ page }) => {
    await page.goto("/post/sample-homebrew-guide");
    await expect(page.getByRole("heading", { name: /📚 맥 필수 유틸리티 가이드/ })).toBeVisible();
    await expect(page.getByText("보고 있는 글")).toBeVisible();
    const tether = page.getByRole("link", { name: /2편/ });
    await expect(tether).toHaveAttribute("href", "/post/tetherlens");
    await tether.click();
    await expect(page).toHaveURL(/\/post\/tetherlens/);
  });
});