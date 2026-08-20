// [FEATURE] 맥 앱 허브 — 역할 카테고리 필터 + 글 목록 (setapp/macmenubar 스타일)
import type { Metadata } from "next";
import Link from "next/link";
import { getPosts, getCategories } from "@/lib/posts";
import PostCard from "@/components/PostCard";
import Pagination from "@/components/Pagination";
import SortSelect from "@/components/SortSelect";

export const revalidate = 60;

export const metadata: Metadata = {
  title: "맥 앱",
  description: "역할별로 찾는 Mac 앱 — Develop, Design, Work, Productivity, System, Media",
};

interface Props {
  searchParams: Promise<{ category?: string; page?: string; sort?: string }>;
}

export default async function AppsPage({ searchParams }: Props) {
  const { category, page: pageStr, sort: sortStr } = await searchParams;
  const page = pageStr ? Number(pageStr) : 1;
  const sort = sortStr === "views" ? ("views" as const) : ("latest" as const);
  const baseFilter = category ? `?category=${category}` : "";

  const [catsRaw, result] = await Promise.all([
    getCategories(),
    // 맥 앱 허브는 맥 앱 관련 글만 — '이야기(stories)' 카테고리는 제외 (단, stories 카테고리 직접 선택 시 표시)
    getPosts({
      categorySlug: category || undefined,
      excludeCategorySlug: category ? undefined : "stories",
      page,
      sort,
    }),
  ]);
  // 맥 앱 허브 사이드바에서는 '이야기' 카테고리 숨김 (앱이 아닌 콘텐츠)
  const cats = catsRaw.filter((c) => c.slug !== "stories");
  const active = category ? cats.find((c) => c.slug === category) : null;

  return (
    <div className="md:flex md:gap-6">
      {/* 좌측: 역할 카테고리 필터 (T-12: 좁아지면 아이콘만 표시) */}
      <aside className="md:w-11 lg:w-56 shrink-0 mb-6 md:mb-0">
        <h1 className="text-2xl font-bold mb-4 md:hidden lg:block">맥 앱</h1>
        <nav className="flex md:flex-col gap-2 overflow-x-auto md:overflow-visible">
          <Link
            href="/apps"
            title="전체"
            className={`inline-flex items-center gap-1.5 rounded-xl px-2.5 py-1.5 text-sm font-medium whitespace-nowrap transition-colors md:w-11 md:justify-center md:px-0 lg:w-auto lg:justify-start lg:px-3 ${!category ? "bg-primary text-white" : "bg-surface-hover text-text-secondary hover:text-text"}`}
          >
            <span aria-hidden className="text-base">🗂️</span>
            <span className="md:hidden lg:inline">전체</span>
          </Link>
          {cats.map((c) => (
            <Link
              key={c.slug}
              href={`/apps?category=${c.slug}`}
              title={`${c.name} (${c.postCount})`}
              className={`inline-flex items-center gap-1.5 rounded-xl px-2.5 py-1.5 text-sm font-medium whitespace-nowrap transition-colors md:w-11 md:justify-center md:px-0 lg:w-auto lg:justify-start lg:px-3 ${active?.slug === c.slug ? "bg-primary text-white" : "bg-surface-hover text-text-secondary hover:text-text"}`}
            >
              <span aria-hidden className="text-base">{c.icon ?? "📁"}</span>
              <span className="md:hidden lg:inline">
                {c.name} ({c.postCount})
              </span>
            </Link>
          ))}
        </nav>
      </aside>

      {/* 우측: 글 목록 */}
      <section className="flex-1">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold">
            {active ? (
              <>
                {active.name}
                {active.description && (
                  <span className="text-sm font-normal text-text-muted ml-2">— {active.description}</span>
                )}
              </>
            ) : (
              "모든 맥 앱"
            )}
          </h2>
          <SortSelect value={sort} basePath={`/apps${baseFilter}`} />
        </div>
          <p className="text-sm text-text-muted mt-1">게시글 {result.total}개</p>

        {result.items.length === 0 ? (
          <p className="text-text-muted text-center py-10">게시글이 없습니다.</p>
        ) : (
          <>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {result.items.map((p) => (
                <PostCard key={p.id} post={p} />
              ))}
            </div>
            <Pagination
              page={result.page}
              totalPages={result.totalPages}
              basePath={`/apps${baseFilter}${sort === "views" ? `${baseFilter ? "&" : "?"}sort=views` : ""}`}
            />
          </>
        )}
      </section>
    </div>
  );
}