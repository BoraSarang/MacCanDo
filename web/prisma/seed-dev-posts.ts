// T-03 검증용 샘플 게시글 (개발 전용)
// 실행: npx tsx prisma/seed-dev-posts.ts
import { PrismaClient } from "@/app/generated/prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";
import "dotenv/config";

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const db = new PrismaClient({ adapter });

async function main() {
  const cat = await db.category.findFirst({ where: { slug: "system" } });
  if (!cat) throw new Error("카테고리 없음: system");

  const existing = await db.post.findFirst({ where: { slug: "sample-cleanmymac-guide" } });
  if (existing) {
    console.log("이미 시드됨 — 건너뜀");
    return;
  }

  await db.post.create({
    data: {
      title: "CleanMyMac X: 맥 저장 공간 정리 완벽 가이드",
      slug: "sample-cleanmymac-guide",
      excerpt: "맥 용량 부족에 시달리고 있다면 CleanMyMac X로 저장 공간을 정리하는 방법을 알아보세요.",
      body: `# CleanMyMac X 완벽 가이드

맥을 오래 쓰다 보면 저장 공간이 부족해지는 경우가 많습니다. **CleanMyMac X**는 이런 문제를 해결하는 대표적인 유틸리티입니다.

## 주요 기능

- 저장 공간 정리
- 악성코드 제거
- 시작 프로그램 관리
- 앱 제거 시 잔여 파일 삭제

## 팁

> 정리는 한 달에 한 번 정도 실행하는 것이 좋습니다.

- [공식 사이트](https://macpaw.com)`,
      contentType: "ARTICLE",
      categories: { create: [{ categoryId: cat.id }] },
      status: "PUBLISHED",
      bodyFormat: "MD",
      publishedAt: new Date(),
      downloadLinks: {
        create: [{ label: "공식 사이트 방문", url: "https://macpaw.com", type: "OFFICIAL", sort: 1 }],
      },
    },
  });

  await db.post.create({
    data: {
      title: "Homebrew 설치부터 사용까지 (M 시리즈 완벽 대응)",
      slug: "sample-homebrew-guide",
      excerpt: "터미널만 알면 맥의 절반은 끝났다. Homebrew 설치부터 자주 쓰는 명령어까지 정리했습니다.",
      body: `# Homebrew 설치 가이드

Homebrew는 맥에서 가장 많이 쓰는 패키지 관리자입니다.

\`\`\`bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
\`\`\`

## 자주 쓰는 명령어

- \`brew install <패키지>\`
- \`brew search <키워드>\`
- \`brew update\``,
      contentType: "ARTICLE",
      categories: { create: [{ categoryId: cat.id }] },
      status: "PUBLISHED",
      bodyFormat: "MD",
      publishedAt: new Date(Date.now() - 86400000),
    },
  });

  console.log("샘플 게시글 2개 시드 완료");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => db.$disconnect());