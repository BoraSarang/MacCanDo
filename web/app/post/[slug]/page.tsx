// [FEATURE] 게시글 상세 — T-03 (MD/HTML 렌더링, 다운로드 게이트 링크 표시)
// T-60: SSG 정적화 — 조회수(PostViewCounter)/게이트(GateCheck)는 클라이언트에서 기록·판정
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import Link from "next/link";
import { renderMarkdown, type AppCardData } from "@/lib/markdown";
import { getPostMetaBySlug, getPostBySlug, getRelatedPosts, getPrevNextPosts } from "@/lib/posts";
import { db } from "@/lib/db"; // T-60: generateStaticParams
import { BodyFormat } from "@/app/generated/prisma/client";
import CommentsSection from "@/components/CommentsSection";
import SeriesList from "@/components/SeriesList";
import PostBody from "@/components/PostBody";
import WelcomeBanner from "@/components/WelcomeBanner";
import { getSeriesForPost } from "@/lib/series";
import { EyeIcon } from "@/components/Icons";
import GateCheck from "./GateCheck";
import PostViewCounter from "./PostViewCounter";

export const revalidate = 60;

// T-60: SSG 대상 등록 — 발행된 글 전체 (ISR 60s)
export async function generateStaticParams() {
  const posts = await db.post.findMany({
    where: { status: "PUBLISHED" },
    select: { slug: true },
  });
  return posts.map((p) => ({ slug: p.slug }));
}

interface Props {
  params: Promise<{ slug: string }>;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const post = await getPostMetaBySlug(slug);
  if (!post) return { title: "게시글 없음" };
  // AI SEO(seoMeta) 값이 있으면 우선 사용 — 없으면 기본(제목/설명) 폴백
  const seo = (post.seoMeta ?? null) as { title?: string; description?: string; tags?: string[]; image?: string } | null;
  const metaTitle = seo?.title || post.title;
  const metaDescription = seo?.description || post.excerpt || undefined;
  const keywords = seo?.tags?.length ? seo.tags.join(", ") : undefined;
  const ogImage = seo?.image || post.thumbnailUrl || undefined;
  return {
    title: metaTitle,
    description: metaDescription,
    keywords,
    openGraph: {
      title: metaTitle,
      description: metaDescription,
      images: ogImage ? [{ url: ogImage }] : undefined,
    },
  };
}

function formatDate(d: Date | null) {
  if (!d) return "";
  return new Intl.DateTimeFormat("ko-KR", { dateStyle: "long" }).format(d);
}

// JSON-LD 구조화 데이터 (BlogPosting) — SEO 향상
function JsonLd({ post, slug }: { post: NonNullable<Awaited<ReturnType<typeof getPostBySlug>>>; slug: string }) {
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";
  const url = `${siteUrl}/post/${slug}`;
  const image = post.thumbnailUrl ? `${siteUrl}${post.thumbnailUrl}` : undefined;
  const authorName = "MacCanDo";
  const publisherName = "MacCanDo";
  const publisherLogo = `${siteUrl}/icon.png`;

  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    headline: post.title,
    description: post.excerpt || undefined,
    image: image ? [image] : undefined,
    datePublished: post.publishedAt?.toISOString() || undefined,
    dateModified: post.updatedAt?.toISOString() || undefined,
    author: {
      "@type": "Person",
      name: authorName,
      url: `${siteUrl}/author/maccando`,
    },
    publisher: {
      "@type": "Organization",
      name: publisherName,
      logo: {
        "@type": "ImageObject",
        url: publisherLogo,
      },
    },
    mainEntityOfPage: {
      "@type": "WebPage",
      "@id": url,
    },
    keywords: post.tags.map((t) => t.tag.name).join(", ") || undefined,
    articleSection: post.categories.map((c) => c.category.name).join(", ") || undefined,
    ...(post.excerpt && { abstract: post.excerpt }),
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
    />
  );
}

export default async function PostPage({ params }: Props) {
  const { slug } = await params;
  // T-60: SSG 정적화 — 조회수/게이트는 클라이언트에서 기록·판정
  const post = await getPostBySlug(slug, false);
  if (!post) notFound();

  // T-17: 정적 페이지(PAGE) — 게시글 전용 UI(카테고리/조회수/썸네일/댓글/시리즈/관련글) 숨김
  const isPage = post.contentType === "PAGE";

  // 다운로드 게이트: 로그인 + 승인 댓글 1개 이상 시 링크 공개 (T-04)
  // T-15: 앱 카드(postAppId) 링크는 제외 — 앱 카드 다운로드는 공개
  const gateLinks = isPage ? [] : post.downloadLinks.filter((dl) => !dl.postAppId);

  // 시리즈 컨텍스트 (하단 목록 — 발행 글만, 순서대로)
  const series = !isPage && post.seriesId ? await getSeriesForPost(post.seriesId) : null;

  // 관련 게시글 (태그 공유 → 카테고리 폴백) + 이전/다음글 (일반 글만) (T-11)
  const [related, prevNext] = isPage
    ? ([[], null] as const)
    : await Promise.all([
        getRelatedPosts(
          post.id,
          post.tags.map((t) => t.tagId),
          post.categories.map((c) => c.categoryId),
          3
        ),
        getPrevNextPosts(slug),
      ]);

  return (
    <article className="max-w-3xl mx-auto">
      <JsonLd post={post} slug={slug} />
      {/* T-18: 비로그인 환영 배너 — 댓글 게이트 참여 유도 (정적 페이지 제외) */}
      {!isPage && <WelcomeBanner />}
      <header className="mb-8">
        {!isPage && (
          <div className="flex items-center gap-2 text-sm text-text-muted mb-3 flex-wrap">
            {post.categories.map((pc) => (
              <Link
                key={pc.category.slug}
                href={`/category/${pc.category.slug}`}
                className="badge bg-primary-soft text-primary"
              >
                {pc.category.name}
              </Link>
            ))}
            <span>{formatDate(post.publishedAt)}</span>
            <span className="inline-flex items-center gap-1">
              <EyeIcon className="w-3.5 h-3.5" />
              <span className="tnum">{post.viewCount}</span>
            </span>
          </div>
        )}
        <h1 className="text-3xl font-bold leading-tight">{post.title}</h1>
        {post.excerpt && <p className="text-text-secondary mt-3">{post.excerpt}</p>}
      </header>

      {/* T-26: 커버 이미지는 목록 카드용 — 본문에서는 표시하지 않음 */}

      {/* 본문: MD 또는 HTML (관리자 작성이므로 HTML 직접 렌더링 허용) */}
      <div className="prose prose-lg max-w-none dark:prose-invert">
        <PostBody
          html={
            post.bodyFormat === BodyFormat.MD
              ? renderMarkdown(post.body, {
                  apps: post.apps.map((a) => ({
                    appName: (a.storeInfo as { appName?: string } | null)?.appName ?? null,
                    storeInfo: a.storeInfo as AppCardData["storeInfo"],
                    homepageUrl: a.homepageUrl,
                    appUrl: a.appUrl,
                    downloadLinks: a.downloadLinks.map((dl) => ({ id: dl.id, label: dl.label })),
                  })),
                  postSlug: post.slug,
                })
              : post.body
          }
        />
      </div>

      {/* 태그 */}
      {!isPage && post.tags.length > 0 && (
        <div className="mt-8 flex flex-wrap gap-2">
          {post.tags.map((pt) => (
            <Link
              key={pt.tag.slug}
              href={`/tag/${pt.tag.slug}`}
              className="text-sm text-primary hover:underline"
            >
              #{pt.tag.name}
            </Link>
          ))}
        </div>
      )}

      {/* 다운로드 링크 (게이트 — 댓글 1개 이상 + 로그인 시 공개, 앱 카드 링크 제외) — T-60: 클라이언트 판정 */}
      {!isPage && gateLinks.length > 0 && (
        <GateCheck
          slug={post.slug}
          links={gateLinks.map((dl) => ({ id: dl.id, label: dl.label, type: dl.type }))}
        />
      )}

      {/* 시리즈 목록 (하단) */}
      {!isPage && <SeriesList series={series} currentId={post.id} />}

      {/* 이전글/다음글 — 일반 글만 (시리즈 글은 시리즈 목록이 역할) (T-11) */}
      {!isPage && prevNext && (prevNext.prev || prevNext.next) && (
        <nav className="mt-10 grid grid-cols-2 gap-3 text-sm" aria-label="이전/다음 글">
          {prevNext.prev ? (
            <Link href={`/post/${prevNext.prev.slug}`} className="card p-4 hover:border-primary/50 hover:shadow-md transition-all">
              <div className="text-xs text-text-muted mb-1">← 이전 글</div>
              <div className="font-semibold line-clamp-2">{prevNext.prev.title}</div>
            </Link>
          ) : (
            <div />
          )}
          {prevNext.next ? (
            <Link href={`/post/${prevNext.next.slug}`} className="card p-4 text-right hover:border-primary/50 hover:shadow-md transition-all">
              <div className="text-xs text-text-muted mb-1">다음 글 →</div>
              <div className="font-semibold line-clamp-2">{prevNext.next.title}</div>
            </Link>
          ) : (
            <div />
          )}
        </nav>
      )}

      {/* 관련 게시글 (T-11) */}
      {!isPage && related.length > 0 && (
        <section className="mt-10">
          <h2 className="text-lg font-bold mb-4">관련 게시글</h2>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            {related.map((r) => (
              <Link key={r.id} href={`/post/${r.slug}`} className="group card overflow-hidden hover:border-primary/50 hover:shadow-md transition-all">
                <div className="relative aspect-[16/8] bg-surface-hover">
                  {r.thumbnailUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={r.thumbnailUrl} alt={r.title} className="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" />
                  ) : (
                    <div className="absolute inset-0 flex items-center justify-center text-3xl font-bold text-primary/15">
                      {r.title.slice(0, 1)}
                    </div>
                  )}
                </div>
                <div className="p-3">
                  <div className="text-sm font-semibold line-clamp-2 group-hover:text-primary transition-colors">{r.title}</div>
                  <div className="text-[11px] text-text-muted mt-1.5">조회 {r.viewCount.toLocaleString()}</div>
                </div>
              </Link>
            ))}
          </div>
        </section>
      )}

      {/* 댓글 — 정적 페이지는 비활성 (T-17) */}
      {!isPage && <CommentsSection slug={post.slug} />}

      {/* T-60: 조회수 기록 (SSG — 클라이언트 1회) */}
      <PostViewCounter slug={post.slug} isPage={isPage} />
    </article>
  );
}