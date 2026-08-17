// [FEATURE] 정적 페이지 E2E — T-17 (PAGE 타입)
// TC-PAGE-001: 6개 페이지 렌더 (게시글 UI 숨김)
// TC-PAGE-002: 홈/검색 목록에 페이지 미노출
// TC-PAGE-003: 푸터 링크 6개
// TC-PAGE-004: 모바일 하단 바 "⋯" 드롭업
import { test, expect } from "@playwright/test";

const PAGES = [
  { slug: "about", title: "MacCanDo 소개" },
  { slug: "privacy-policy", title: "개인정보 처리방침" },
  { slug: "disclaimer", title: "면책 조항" },
  { slug: "terms", title: "이용약관" },
  { slug: "faq", title: "자주 묻는 질문 (FAQ)" },
  { slug: "contact", title: "문의하기" },
];

test.describe("정적 페이지", () => {
  test("TC-PAGE-001: 페이지 렌더 — 게시글 UI(카테고리/조회수/댓글/관련글) 숨김", async ({ page }) => {
    for (const p of PAGES) {
      const res = await page.goto(`/post/${p.slug}`);
      expect(res?.status(), `${p.slug} 200`).toBe(200);
      await expect(page.getByRole("heading", { level: 1 })).toContainText(p.title);
      // 게시글 전용 UI 없음
      await expect(page.getByText(/👁 \d/)).toHaveCount(0);
      await expect(page.getByText("관련 게시글")).toHaveCount(0);
      await expect(page.getByRole("heading", { name: /^댓글 \d/ })).toHaveCount(0);
      // 게이트 섹션 없음
      await expect(page.locator("section", { hasText: "📥 다운로드" })).toHaveCount(0);
    }
  });

  test("TC-PAGE-002: 목록 제외 — 홈·검색에 페이지 미노출", async ({ page }) => {
    await page.goto("/");
    for (const p of PAGES) {
      await expect(page.getByRole("heading", { name: p.title })).toHaveCount(0);
    }
    // 검색 — 페이지 본문 키워드는 검색돼도 목록 제외
    await page.goto("/search?q=면책");
    await expect(page.getByRole("heading", { name: "면책 조항" })).toHaveCount(0);
    await expect(page.getByRole("heading", { name: "검색 결과" })).toBeVisible();
  });

  test("TC-PAGE-003: 푸터 링크 6개 — 사이트 정보 네비", async ({ page }) => {
    await page.goto("/");
    const nav = page.getByRole("navigation", { name: "사이트 정보" });
    for (const p of PAGES) {
      await expect(nav.getByRole("link", { name: p.title === "자주 묻는 질문 (FAQ)" ? "FAQ" : p.title === "문의하기" ? "Contact Us" : p.title === "이용약관" ? "Terms of Service" : p.title === "개인정보 처리방침" ? "Privacy Policy" : p.title === "면책 조항" ? "Disclaimer" : "About" })).toBeVisible();
    }
  });

  test("TC-PAGE-004: 모바일 하단 바 — ⋯ 드롭업 6개 링크", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto("/post/about");
    const bar = page.locator("#mobile-bar");
    await expect(bar).toBeVisible();
    await bar.getByRole("button", { name: "더보기" }).click();
    await expect(page.getByText("사이트 정보")).toBeVisible();
    const expected = ["About", "Privacy Policy", "Disclaimer", "Terms of Service", "FAQ", "Contact Us"];
    for (const label of expected) {
      await expect(page.locator("#mobile-bar").getByRole("link", { name: label })).toBeVisible();
    }
    await page.getByRole("button", { name: "닫기" }).click();
    await expect(page.locator("#mobile-bar").getByRole("link", { name: "About" })).toHaveCount(0);
  });
});
