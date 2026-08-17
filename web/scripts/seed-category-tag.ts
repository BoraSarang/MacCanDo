// T-10-2: 카테고리 재구성 + 글 매핑 + contentType + 태그 시드
// T-14: 카테고리 10개 확장 (웹 확장/기타/OS/게임) + icon 추가
import { db } from "@/lib/db";

const CATEGORIES = [
  { slug: "develop", name: "Develop", description: "코딩/터미널/AI 도구", icon: "💻" },
  { slug: "design", name: "Design", description: "디자인/이미지/컬러", icon: "🎨" },
  { slug: "work", name: "Work", description: "문서/메모/할 일/미팅", icon: "💼" },
  { slug: "productivity", name: "Productivity", description: "런처/클립보드/창 관리/단축키", icon: "⚡" },
  { slug: "system", name: "System", description: "정리/보안/모니터링", icon: "🛠️" },
  { slug: "media", name: "Media", description: "오디오/비디오/스크린샷", icon: "🎬" },
  { slug: "web-extension", name: "웹 확장", description: "Chrome/Firefox/Safari 확장 프로그램", icon: "🧩" },
  { slug: "etc", name: "기타", description: "분류하기 애매한 나머지", icon: "📦" },
  { slug: "os", name: "OS", description: "macOS 설치/버전/업데이트", icon: "🍎" },
  { slug: "games", name: "게임", description: "맥에서 즐기는 게임", icon: "🎮" },
];

// slug -> { contentType, categories: [slug...] }
const POST_MAP: Record<string, { contentType: "ARTICLE" | "TIP" | "NEWS"; cats: string[] }> = {
  "mac-first-startup-guide": { contentType: "TIP", cats: ["system", "work"] },
  "sample-homebrew-guide": { contentType: "ARTICLE", cats: ["develop"] },
  "cleanmymac-x-mac-storage-cleanup-guide": { contentType: "ARTICLE", cats: ["system"] },
  tetherlens: { contentType: "ARTICLE", cats: ["productivity", "work"] },
  "dev-mac-productivity-apps": { contentType: "ARTICLE", cats: ["develop", "productivity"] },
  "iterm2-tmux-oh-my-zsh": { contentType: "ARTICLE", cats: ["develop"] },
  "ai-coding-assistant-guide": { contentType: "ARTICLE", cats: ["develop"] },
  "macos-tahoe-iphone-mirroring-liquid-glass": { contentType: "NEWS", cats: ["os"] }, // T-14: system → os
  "finder-200-percent-guide": { contentType: "TIP", cats: ["productivity", "work"] },
  "mac-smart-folder-search": { contentType: "TIP", cats: ["productivity", "work"] },
  "mac-password-manager-2fa": { contentType: "TIP", cats: ["system"] },
  "mac-privacy-settings-5": { contentType: "TIP", cats: ["system"] },
  "mac-continuity-guide": { contentType: "TIP", cats: ["work", "productivity"] },
  "airdrop-airplay-guide": { contentType: "TIP", cats: ["media", "productivity"] },
};

const TAGS: Record<string, string[]> = {
  "sample-homebrew-guide": ["Homebrew", "터미널"],
  "iterm2-tmux-oh-my-zsh": ["터미널", "생산성"],
  "ai-coding-assistant-guide": ["AI", "개발자"],
  "dev-mac-productivity-apps": ["개발자", "생산성", "단축키"],
  "mac-first-startup-guide": ["단축키", "첫 설정"],
  "finder-200-percent-guide": ["파일 관리", "단축키"],
  "mac-smart-folder-search": ["파일 관리", "검색"],
  "cleanmymac-x-mac-storage-cleanup-guide": ["클린업", "저장 공간"],
  "mac-password-manager-2fa": ["보안", "2FA"],
  "mac-privacy-settings-5": ["보안", "프라이버시"],
  "mac-continuity-guide": ["연속성", "아이폰 연동"],
  "airdrop-airplay-guide": ["에어드롭", "AirPlay"],
  tetherlens: ["유틸리티", "데이터의 끝판왕"],
  "macos-tahoe-iphone-mirroring-liquid-glass": ["macOS", "애플", "iPhone Mirroring"],
};

async function main() {
  await db.postCategory.deleteMany({});
  await db.postTag.deleteMany({});
  await db.tag.deleteMany({});
  await db.category.deleteMany({});
  const catById: Record<string, string> = {};
  for (let i = 0; i < CATEGORIES.length; i++) {
    const c = CATEGORIES[i];
    const created = await db.category.create({ data: { slug: c.slug, name: c.name, description: c.description, icon: c.icon, sort: i } });
    catById[c.slug] = created.id;
  }
  console.log("카테고리 10개 생성 완료");

  const posts = await db.post.findMany({ select: { id: true, slug: true } });
  const bySlug = new Map(posts.map((p) => [p.slug, p.id]));

  for (const [slug, m] of Object.entries(POST_MAP)) {
    const postId = bySlug.get(slug);
    if (!postId) {
      console.log("SKIP (없음):", slug);
      continue;
    }
    await db.post.update({
      where: { id: postId },
      data: {
        contentType: m.contentType,
        categories: { create: m.cats.map((s) => ({ categoryId: catById[s] })) },
      },
    });
  }
  console.log("글 매핑 완료");

  for (const [slug, names] of Object.entries(TAGS)) {
    const postId = bySlug.get(slug);
    if (!postId) continue;
    for (const name of names) {
      const existing = await db.tag.findUnique({ where: { name } });
      const tag = existing ?? (await db.tag.create({ data: { name, slug: name.toLowerCase().replace(/[^a-z0-9가-힣]+/g, "-") } }));
      await db.postTag.create({ data: { postId, tagId: tag.id } });
    }
  }
  console.log("태그 시드 완료");

  const pc = await db.postCategory.count();
  const pt = await db.postTag.count();
  const t = await db.tag.count();
  console.log(`최종: PostCategory ${pc}건, PostTag ${pt}건, Tag ${t}개`);
  await db.$disconnect();
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});