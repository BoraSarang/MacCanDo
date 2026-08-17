// [FEATURE] 게시글 상세 — T-03 (MD/HTML 렌더링, 조회수, 다운로드 게이트 링크 표시)
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import Link from "next/link";
import { renderMarkdown, type AppCardData } from "@/lib/markdown";
import { getPostBySlug, getRelatedPosts, getPrevNextPosts } from "@/lib/posts";
import { getUserApprovedCommentCount } from "@/lib/comments";
import { auth } from "@/auth";
import { logger } from "@/lib/logger";
import { BodyFormat } from "@/app/generated/prisma/client";
import CommentsSection from "@/components/CommentsSection";
import SeriesList from "@/components/SeriesList";
import PostBody from "@/components/PostBody";
import { getSeriesForPost } from "@/lib/series";

export const revalidate = 60;

interface Props {
  params: Promise<{ slug: string }>;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const post = await getPostBySlug(slug, false);
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

export default async function PostPage({ params }: Props) {
  const { slug } = await params;
  const post = await getPostBySlug(slug);
  if (!post) notFound();

  // 다운로드 게이트: 로그인 + 승인 댓글 1개 이상 시 링크 공개 (T-04)
  // T-15: 앱 카드(postAppId) 링크는 제외 — 앱 카드 다운로드는 공개
  const gateLinks = post.downloadLinks.filter((dl) => !dl.postAppId);
  const session = await auth();
  const commentCount = session?.user?.id
    ? await getUserApprovedCommentCount(session.user.id)
    : 0;
  const gateUnlocked = (session?.user?.id ? commentCount >= 1 : false) && gateLinks.length > 0;
  logger.info("PostDetail", `게이트 판정 (slug=${slug}, user=${session?.user?.id ?? "-"}, comments=${commentCount})`);

  // 시리즈 컨텍스트 (하단 목록 — 발행 글만, 순서대로)
  const series = post.seriesId ? await getSeriesForPost(post.seriesId) : null;

  // 관련 게시글 (태그 공유 → 카테고리 폴백) + 이전/다음글 (일반 글만) (T-11)
  const [related, prevNext] = await Promise.all([
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
      <header className="mb-8">
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
          <span>👁 {post.viewCount}</span>
        </div>
        <h1 className="text-3xl font-bold leading-tight">{post.title}</h1>
        {post.excerpt && <p className="text-text-secondary mt-3">{post.excerpt}</p>}
      </header>

      {post.thumbnailUrl && (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={post.thumbnailUrl} alt={post.title} className="w-full rounded-xl mb-8" />
      )}

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
      {post.tags.length > 0 && (
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

      {/* 다운로드 링크 (게이트 — 댓글 1개 이상 + 로그인 시 공개, 앱 카드 링크 제외) */}
      {gateLinks.length > 0 && (
        <section className="mt-10 card p-6 border-primary/30 bg-primary-soft/50">
          <h2 className="font-bold text-lg mb-1">📥 다운로드</h2>
          {gateUnlocked ? (
            <>
              <p className="text-sm text-text-secondary mb-4">댓글 작성 감사합니다! 다운로드 링크가 공개되었습니다.</p>
              {gateLinks.map((dl) => (
                <Link
                  key={dl.id}
                  href={`/post/${post.slug}/download/${dl.id}`}
                  className="block border border-border-strong bg-bg rounded-lg px-4 py-3 mb-2 hover:border-primary/50 hover:shadow-sm transition-all"
                >
                  <span className="font-semibold">{dl.label}</span>
                  <span className="text-xs text-text-muted ml-2">
                    ({dl.type === "OFFICIAL" ? "파일" : "웹 페이지"})
                  </span>
                </Link>
              ))}
            </>
          ) : (
            <p className="text-sm text-text-secondary mb-4">
              {session?.user
                ? "다운로드 링크를 보려면 댓글을 1개 이상 남겨주세요. (관리자 승인 후 공개됩니다)"
                : "다운로드 링크를 보려면 Google 로그인 후 댓글을 1개 이상 남겨주세요."}
            </p>
          )}
        </section>
      )}

      {/* 시리즈 목록 (하단) */}
      <SeriesList series={series} currentId={post.id} />

      {/* 이전글/다음글 — 일반 글만 (시리즈 글은 시리즈 목록이 역할) (T-11) */}
      {prevNext && (prevNext.prev || prevNext.next) && (
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
      {related.length > 0 && (
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

      {/* 댓글 */}
      <CommentsSection slug={post.slug} />
    </article>
  );
}