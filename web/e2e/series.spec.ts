// [FEATURE] E2E — 시리즈/카테고리(역할)/허브/팁/태그/헬스 (TC-E2E-WEB-003)
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

test.describe("맥 앱 허브 (역할 카테고리)", () => {
  test("좌측 필터 6개 + 전체 글 목록", async ({ page }) => {
    await page.goto("/apps");
    const filters = page.locator("main aside a[href^='/apps?category=']");
    await expect(filters).toHaveCount(6);
    await expect(page.getByRole("heading", { name: "모든 맥 앱" })).toBeVisible();
    await expect(page.locator("main a[href^='/post/']").first()).toBeVisible();
  });

  test("Develop 필터 → 개발 글만 (2개) + 설명 노출", async ({ page }) => {
    await page.goto("/apps?category=develop");
    await expect(page.getByText("Develop", { exact: true }).first()).toBeVisible();
    await expect(page.getByText("코딩/터미널/AI 도구")).toBeVisible();
    const cards = page.locator("main a[href^='/post/']");
    await expect(cards).toHaveCount(2);
  });

  test("카드에 다중 카테고리 배지 표시", async ({ page }) => {
    await page.goto("/apps?category=work");
    const firstCard = page.locator("main a[href^='/post/']").first();
    await expect(firstCard.locator("a[href='/category/work']")).toBeVisible();
  });
});

test.describe("카테고리", () => {
  test("Develop 카테고리 글 목록", async ({ page }) => {
    await page.goto("/category/develop");
    await expect(page.getByRole("heading", { name: "Develop" })).toBeVisible();
    await expect(page.locator("main a[href^='/post/']").first()).toBeVisible();
  });
});

test.describe("맥 팁/맥 소식", () => {
  test("/tips — TIP 글만 (7개)", async ({ page }) => {
    await page.goto("/tips");
    await expect(page.getByRole("heading", { name: "맥 팁" })).toBeVisible();
    const cards = page.locator("main a[href^='/post/']");
    await expect(cards).toHaveCount(7);
  });

  test("/news — NEWS 글 노출", async ({ page }) => {
    await page.goto("/news");
    await expect(page.getByRole("heading", { name: "맥 소식" })).toBeVisible();
    await expect(page.locator("main a[href^='/post/']").first()).toContainText("macOS Tahoe");
  });
});

test.describe("태그", () => {
  test("글 상세에 태그 노출 + 태그 모아보기", async ({ page }) => {
    await page.goto("/post/ai-coding-assistant-guide");
    await expect(page.getByRole("link", { name: "#AI" })).toBeVisible();
    await expect(page.getByRole("link", { name: "#개발자" })).toBeVisible();
    await page.getByRole("link", { name: "#AI" }).click();
    await expect(page).toHaveURL(/\/tag\/ai/);
    await expect(page.getByRole("heading", { name: "#AI" })).toBeVisible();
    await expect(page.locator("main a[href^='/post/']")).toHaveCount(1);
  });
});

test.describe("헬스", () => {
  test("/health 200", async ({ request }) => {
    const res = await request.get("/api/health");
    expect(res.status()).toBe(200);
  });
});