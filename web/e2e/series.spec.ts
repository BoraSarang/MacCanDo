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
  test("좌측 필터 10개 + 전체 글 목록", async ({ page }) => {
    await page.goto("/apps");
    const filters = page.locator("main aside a[href^='/apps?category=']");
    await expect(filters).toHaveCount(10);
    await expect(page.getByRole("heading", { name: "맥 앱", exact: true })).toBeVisible();
    await expect(page.locator("main a[href^='/post/']").first()).toBeVisible();
  });

  test("사이드바 접힘: 좁은 화면(900px) 아이콘만, 넓은 화면(1280px) 라벨", async ({ page }) => {
    await page.setViewportSize({ width: 900, height: 800 });
    await page.goto("/apps");
    const devLink = page.locator("main aside a[href='/apps?category=develop']");
    await expect(devLink).toBeVisible();
    await expect(devLink.getByText("Develop")).not.toBeVisible();

    await page.setViewportSize({ width: 1280, height: 800 });
    await expect(devLink.getByText("Develop")).toBeVisible();
  });

  test("Develop 필터 → 개발 글만 (4개) + 설명 노출", async ({ page }) => {
    await page.goto("/apps?category=develop");
    await expect(page.getByText("Develop", { exact: true }).first()).toBeVisible();
    await expect(page.getByText("코딩/터미널/AI 도구")).toBeVisible();
    const cards = page.locator("main a[href^='/post/']");
    await expect(cards).toHaveCount(4);
  });

  test("카드에 다중 카테고리 배지 표시", async ({ page }) => {
    await page.goto("/apps?category=work");
    const firstCard = page.locator("main a[href^='/post/']").first();
    await expect(firstCard.locator("a[href='/category/work']")).toBeVisible();
  });

  test("정렬 드롭다운 — 조회수순 전환 시 Homebrew 1위", async ({ page }) => {
    await page.goto("/apps");
    const sort = page.getByLabel("정렬");
    await expect(sort).toBeVisible();
    await sort.selectOption("조회수순");
    await expect(page).toHaveURL(/sort=views/);
    const first = page.locator("main a[href^='/post/']").first();
    await expect(first).toContainText("Homebrew");
  });
});

test.describe("홈 광고 슬롯 (시리즈 배너 + 추천)", () => {
  test("시리즈 배너 4개 + 추천 게시글 (대형 1 + 소형 2)", async ({ page }) => {
    await page.goto("/");
    const banner = page.getByRole("heading", { name: "시리즈", exact: true });
    await expect(banner).toBeVisible();
    await expect(page.locator("main section").filter({ has: banner }).locator("a[href^='/series/']")).toHaveCount(4);

    const feat = page.getByRole("heading", { name: "추천 게시글" });
    await expect(feat).toBeVisible();
    const featSection = page.locator("main section").filter({ has: feat });
    await expect(featSection.locator("a[href^='/post/']").first()).toBeVisible();
    await expect(featSection.locator("a[href^='/post/']")).toHaveCount(3);
  });

  test("추천 순서: 관리자 지정 글 우선 (Homebrew 1위)", async ({ page }) => {
    await page.goto("/");
    const feat = page.getByRole("heading", { name: "추천 게시글" });
    const first = page.locator("main section").filter({ has: feat }).locator("a[href^='/post/']").first();
    await expect(first).toContainText("Homebrew");
  });
});

test.describe("카테고리", () => {
  test("Develop 카테고리 글 목록", async ({ page }) => {
    await page.goto("/category/develop");
    await expect(page.getByRole("heading", { name: "Develop" })).toBeVisible();
    await expect(page.locator("main a[href^='/post/']").first()).toBeVisible();
  });

  test("OS 카테고리: macOS Tahoe 글 노출", async ({ page }) => {
    await page.goto("/category/os");
    await expect(page.getByRole("heading", { name: "OS", exact: true })).toBeVisible();
    const cards = page.locator("main a[href^='/post/']");
    await expect(cards).toHaveCount(1);
    await expect(cards.first()).toContainText("macOS Tahoe");
  });

  test("게임 카테고리: 빈 상태 안내", async ({ page }) => {
    await page.goto("/category/games");
    await expect(page.getByText("게시글이 없습니다.")).toBeVisible();
  });
});

test.describe("메뉴", () => {
  test("헤더에 OS/게임 메뉴", async ({ page }) => {
    await page.goto("/");
    const menu = page.locator("header nav");
    await expect(menu.getByRole("link", { name: "OS" })).toBeVisible();
    await expect(menu.getByRole("link", { name: "게임" })).toBeVisible();
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

test.describe("글 상세 확장 (관련 게시글 + 이전/다음)", () => {
  test("관련 게시글 (태그 공유)", async ({ page }) => {
    await page.goto("/post/ai-coding-assistant-guide");
    await expect(page.getByRole("heading", { name: "관련 게시글" })).toBeVisible();
    const related = page
      .locator("main section")
      .filter({ has: page.getByRole("heading", { name: "관련 게시글" }) })
      .locator("a[href^='/post/']");
    await expect(related.first()).toBeVisible();
  });

  test("시리즈 글: 이전/다음 없음 (시리즈 목록이 역할)", async ({ page }) => {
    await page.goto("/post/sample-homebrew-guide");
    await expect(page.getByLabel("이전/다음 글")).toHaveCount(0);
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

  test("한글 태그 slug 모아보기 (/tag/애플)", async ({ page }) => {
    await page.goto("/post/macos-tahoe-iphone-mirroring-liquid-glass");
    await page.getByRole("link", { name: "#애플" }).click();
    await expect(page).toHaveURL(/\/tag\/%EC%95%A0%ED%94%8C/);
    await expect(page.getByRole("heading", { name: "#애플" })).toBeVisible();
  });
});

test.describe("헬스", () => {
  test("/health 200", async ({ request }) => {
    const res = await request.get("/api/health");
    expect(res.status()).toBe(200);
  });
});