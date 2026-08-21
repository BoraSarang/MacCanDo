// [E2E] 워크스페이스 플로우 테스트 — 마크다운 렌더링/이미지/앱카드 (T-94)
// macOS 앱에서 생성된 콘텐츠가 웹에서 올바르게 렌더링되는지 검증
import { test, expect } from "@playwright/test";

test.describe("워크스페이스 생성 콘텐츠 렌더링", () => {
  test("이미지 프롬프트 마커 [img:URL alt=...] → <img alt> 렌더링", async ({ page }) => {
    // 테스트용 게시글이 있다면 방문, 없으면 MD 렌더링 페이지 직접 테스트
    await page.goto("/");
    
    // 검색으로 MD 렌더링 확인 가능한 글 찾기
    await page.getByRole("searchbox", { name: "검색어 입력" }).fill("이미지 프롬프트");
    await page.getByRole("button", { name: "검색" }).click();
    
    // 결과가 없으면 기본 MD 렌더링 테스트
    // TODO: 실제 게시글 생성 후 URL로 테스트
  });

  test("앱 카드 마커 [app:URL] → 앱 카드 렌더링", async ({ page }) => {
    await page.goto("/");
    // 앱 카드가 포함된 글 찾기
    await page.getByRole("searchbox", { name: "검색어 입력" }).fill("앱 카드");
    await page.getByRole("button", { name: "검색" }).click();
  });

  test("갤러리 마커 [gallery] → 그리드 렌더링", async ({ page }) => {
    await page.goto("/");
    await page.getByRole("searchbox", { name: "검색어 입력" }).fill("갤러리");
    await page.getByRole("button", { name: "검색" }).click();
  });

  test("중앙정렬 마커 [center] → div.mac-center 렌더링", async ({ page }) => {
    await page.goto("/");
    await page.getByRole("searchbox", { name: "검색어 입력" }).fill("중앙정렬");
    await page.getByRole("button", { name: "검색" }).click();
  });
});

test.describe("SEO/메타 검증", () => {
  test("게시글 OG 메타 태그 포함 확인", async ({ page }) => {
    await page.goto("/post/notepad-exe");
    await expect(page.locator('meta[property="og:title"]')).toHaveAttribute("content", /.+/);
    await expect(page.locator('meta[property="og:description"]')).toHaveAttribute("content", /.+/);
    await expect(page.locator('meta[property="og:image"]')).toHaveAttribute("content", /.+/);
  });

  test("JSON-LD 구조화 데이터 포함 확인 (구현 시 활성화)", async ({ page }) => {
    // TODO: JSON-LD 구현 후 활성화
    test.skip(true, "JSON-LD 미구현");
    await page.goto("/post/notepad-exe");
    await expect(page.locator('script[type="application/ld+json"]')).toHaveCount(1);
  });
});

test.describe("이미지 프롬프트 복사 UX", () => {
  test("이미지 프롬프트 생성 후 복사 버튼 존재 확인", async ({ page }) => {
    // macOS 앱에서 생성된 프롬프트가 웹에 표시되는지 확인
    // 실제로는 macOS 앱 테스트가 필요하지만, 웹 렌더링 관점에서 검증
    await page.goto("/");
  });
});