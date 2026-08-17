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
    await expect(page.getByRole("heading", { name: /📚 맥을 처음 접할 때 필요한 필수 앱/ })).toBeVisible();
    await expect(page.getByText("보고 있는 글")).toBeVisible();
    const tether = page.getByRole("link", { name: /4편/ });
    await expect(tether).toHaveAttribute("href", "/post/tetherlens");
    await tether.click();
    await expect(page).toHaveURL(/\/post\/tetherlens/);
  });

  test("다크모드: 본문 가독성 (prose-invert)", async ({ page }) => {
    await page.emulateMedia({ colorScheme: "dark" });
    await page.goto("/post/sample-homebrew-guide");
    await expect(page.locator("html.dark")).toBeVisible();
    const pColor = await page.locator(".prose p").first().evaluate((el) => getComputedStyle(el).color);
    const bg = await page.locator("body").evaluate((el) => getComputedStyle(el).backgroundColor);
    const luminance = (rgb: string) => {
      const m = rgb.match(/\d+/g);
      if (!m) return 0;
      const [r, g, b] = m.map(Number);
      return 0.299 * r + 0.587 * g + 0.114 * b;
    };
    const bgLum = luminance(bg);
    const textLum = luminance(pColor);
    expect(bgLum).toBeLessThan(80); // 어두운 배경
    expect(textLum).toBeGreaterThan(bgLum + 120); // 본문이 배경보다 충분히 밝음
  });

  test("코드 블록 복사 버튼: 클릭 시 코드 클립보드 복사", async ({ page }) => {
    await page.context().grantPermissions(["clipboard-read", "clipboard-write"]);
    await page.goto("/post/iterm2-tmux-oh-my-zsh");
    const btn = page.locator(".prose pre [data-copy-btn]").first();
    await expect(btn).toBeVisible();
    await btn.click();
    await expect(btn).toHaveText("✓");
    const clip = await page.evaluate(() => navigator.clipboard.readText());
    expect(clip).toContain("brew install tmux");
  });
});