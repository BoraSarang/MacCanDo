// T-17 시드: 정적 페이지 6종 (about/privacy-policy/disclaimer/terms/faq/contact)
// 이미 존재하면 스킵 — 이후 수정은 macOS 에디터에서
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "@/app/generated/prisma/client";

const PAGES: { slug: string; title: string; excerpt: string; body: string }[] = [
  {
    slug: "about",
    title: "MacCanDo 소개",
    excerpt: "맥으로 이것도 할 수 있다 — 유용한 프로그램 소개와 꿀팁을 큐레이션합니다.",
    body: `MacCanDo는 **"맥으로 이것도 할 수 있다"**라는 주제로 운영되는 맥(Mac) 큐레이션 블로그입니다.

## 하는 일

- **맥 앱 소개**: 개발·생산성·게임 등 유용한 macOS 앱을 선별해 소개합니다
- **꿀팁 가이드**: Finder, 터미널, 단축키 등 일상에 바로 써먹는 맥 사용법을 정리합니다
- **맥 소식**: macOS 업데이트와 관련 뉴스를 요약합니다

## 운영 원칙

- 모든 앱 정보는 **공식 스토어/홈페이지 기준**으로 정리합니다
- 각 글의 앱 카드에서 다운로드 링크와 공식 홈페이지를 바로 확인할 수 있습니다
- 문의 사항은 [Contact Us](/post/contact) 페이지를 이용해 주세요`,
  },
  {
    slug: "privacy-policy",
    title: "개인정보 처리방침",
    excerpt: "MacCanDo가 수집하는 정보와 처리 방식에 대해 안내합니다.",
    body: `MacCanDo(이하 "사이트")는 이용자의 개인정보를 소중히 여기며, 아래와 같이 처리방침을 공지합니다.

## 수집하는 정보

- **Google 로그인**: 댓글 작성을 위해 Google 계정의 이름·이메일을 받습니다 (Google OAuth 제공 범위 내)
- **댓글**: 이용자가 직접 작성한 댓글 내용 (관리자 승인 후 공개)
- **방문 정보**: 글 조회수 집계용 IP (통계 목적, 개인 식별 없음)

## 저장과 보관

- 수집 정보는 사이트 운영 목적으로만 사용하며, 회원 탈퇴·삭제 요청 시 지체 없이 파기합니다
- 삭제 요청은 [Contact Us](/post/contact)로 보내주세요

## 쿠키·로컬스토리지

- 다크모드 설정 등 UI 환경값을 로컬스토리지에 저장합니다
- 제3자 광고 쿠키는 사용하지 않습니다

## 안내

- 운영자가 게시글을 관리하며, 필요한 경우 작성자 정보를 열람할 수 있습니다`,
  },
  {
    slug: "disclaimer",
    title: "면책 조항",
    excerpt: "사이트에 게시된 앱·링크 정보에 대한 안내입니다.",
    body: `MacCanDo에 게시된 정보와 관련한 면책 사항을 안내합니다.

## 정보의 출처

- 앱 이름·버전·가격·호환성 등 정보는 **공식 App Store·홈페이지**에서 자동/수동으로 가져온 것입니다
- 앱 정보는 언제든 변경될 수 있으며, 사이트에 표시된 내용이 최신이 아닐 수 있습니다

## 상표권

- 등장하는 앱·제품·서비스 이름과 로고는 각 소유자의 상표입니다
- 본 사이트는 해당 앱들과 제휴 관계가 아닙니다

## 책임 한계

- 사이트의 다운로드 링크를 통해 설치한 프로그램으로 인한 손해에 대해 사이트는 책임을 지지 않습니다
- 정보의 오류로 인한 손해에 대해서도 사이트는 책임을 지지 않습니다`,
  },
  {
    slug: "terms",
    title: "이용약관",
    excerpt: "MacCanDo 서비스 이용 조건을 안내합니다.",
    body: `MacCanDo(이하 "서비스") 이용과 관련한 조건을 안내합니다.

## 다운로드 게이트 규칙

- 일부 글의 다운로드 링크는 **Google 로그인 + 승인 댓글 1개 이상**일 때 공개됩니다
- 댓글은 관리자 승인 후 공개됩니다
- 앱 카드의 다운로드 버튼은 로그인 없이 공개입니다

## 이용자의 의무

- **금지 행위**: 스팸 댓글, 타인 사칭, 허위 정보 유포, 서비스 방해 행위
- 위반 시 댓글 삭제·서비스 이용 제한될 수 있습니다

## 서비스 변경

- 서비스는 예고 없이 개선·변경될 수 있습니다
- 약관 변경 시 본 페이지를 통해 안내합니다

## 문의

- 약관 관련 문의는 [Contact Us](/post/contact)로 보내주세요`,
  },
  {
    slug: "faq",
    title: "자주 묻는 질문 (FAQ)",
    excerpt: "다운로드 게이트, 앱 정보에 대한 자주 묻는 질문 모음입니다.",
    body: `자주 묻는 질문을 모았습니다. 여기서 해결되지 않으면 [Contact Us](/post/contact)로 문의해 주세요.

## 다운로드 게이트

### 왜 댓글을 남겨야 다운로드가 되나요?
글의 퀄리티와 커뮤니티 활성화를 위해 댓글 1개 이상을 조건으로 걸고 있습니다. 로그인 후 댓글을 남기면 관리자 승인 뒤 다운로드 링크가 공개됩니다.

### 댓글을 남겼는데 링크가 안 보여요?
댓글은 관리자 승인 후 반영됩니다. 잠시 후 새로고침해 주세요.

## 앱 카드

### 앱 정보(버전·가격)가 최신이 아닌데요?
앱 카드 정보는 App Store 공개 데이터 기준입니다. 스토어 반영 시점에 따라 차이가 있을 수 있습니다.

### 앱이 App Store에 없는데 어떻게 받나요?
일부 앱(iTerm2, Rectangle 등)은 공식 홈페이지에서만 배포합니다. 앱 카드의 다운로드 버튼이 공식 배포처로 연결됩니다.

## 기타

### 운영자에게 직접 연락하려면?
[Contact Us](/post/contact) 페이지를 이용해 주세요.`,
  },
  {
    slug: "contact",
    title: "문의하기",
    excerpt: "운영자에게 문의할 수 있는 페이지입니다.",
    body: `운영자에게 문의해 주세요.

## 문의 방법

- **이메일**: 문의는 아래 이메일로 보내주세요
- **내용 안내**: 문의 시 문제가 발생한 글의 주소(URL)와 구체적인 상황을 함께 적어주시면 빠른 해결에 도움이 됩니다

## 처리 안내

- 영업일 기준 **2~3일 내** 답변을 드리기 위해 노력합니다
- 개인정보 삭제 요청, 저작권 관련 문의도 이 페이지를 통해 접수합니다

> 답변이 필요한 문의는 이메일을 꼭 남겨주세요.`,
  },
];

async function main() {
  const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
  const db = new PrismaClient({ adapter });
  let created = 0;
  for (const p of PAGES) {
    const exists = await db.post.findUnique({ where: { slug: p.slug } });
    if (exists) {
      console.log(`SKIP: ${p.slug} (이미 존재)`);
      continue;
    }
    await db.post.create({
      data: {
        title: p.title,
        slug: p.slug,
        contentType: "PAGE",
        bodyFormat: "MD",
        body: p.body,
        excerpt: p.excerpt,
        status: "PUBLISHED",
        publishedAt: new Date(),
        seoMeta: { title: p.title, description: p.excerpt },
      },
    });
    created++;
    console.log(`OK: ${p.slug}`);
  }
  console.log(`완료 — 생성 ${created}개 / 스킵 ${PAGES.length - created}개`);
  await db.$disconnect();
}
main();
