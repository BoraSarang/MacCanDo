// [E2E] 스모크 테스트 — 홈/상세/검색 (표준 7.7, TC-E2E 웹 버전)
// 읽기 위주: 조회수 POST 1회 영향만 (실 DB 허용 범위)
import { test, expect } from "@playwright/test";

test("홈 — 히어로 + 게시글 카드 렌더링", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1 })).toContainText("맥");
  // 게시글 카드 목록 (제목 링크 1개 이상)
  await expect(page.locator("main a[href^='/post/']").first()).toBeVisible();
  // 헤더 네비게이션
  await expect(page.getByRole("navigation").first()).toContainText("맥 앱");
});

test("글 상세 — 제목/본문/다운로드 게이트 렌더링", async ({ page }) => {
  await page.goto("/post/notepad-exe");
  await expect(page.getByRole("heading", { level: 1 })).toContainText("Notepad.exe");
  await expect(page.locator("main").getByText("장점")).toBeVisible();
  // 게이트 글: 다운로드 섹션 잠금 문구 (미로그인)
  await page.goto("/post/cleanmymac-x-mac-storage-cleanup-guide");
  const dlSection = page.locator("section").filter({ hasText: "다운로드" }).first();
  await expect(dlSection).toContainText("Google 로그인 후 댓글");
});

test("검색 — 쿼리 입력 → 결과 표시", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("searchbox", { name: "검색어 입력" }).fill("맥");
  await page.getByRole("button", { name: "검색" }).click();
  await expect(page).toHaveURL(/search|q=/);
});

test("카테고리 페이지 — 게시글 목록 렌더링", async ({ page }) => {
  await page.goto("/category/develop");
  await expect(page.locator("main a[href^='/post/']").first()).toBeVisible();
});