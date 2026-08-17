// [FEATURE] 맥 앱 허브 — 역할 카테고리 필터 + 글 목록 (setapp/macmenubar 스타일)
import type { Metadata } from "next";
import Link from "next/link";
import { getPosts, getCategories } from "@/lib/posts";
import PostCard from "@/components/PostCard";
import Pagination from "@/components/Pagination";

export const revalidate = 60;

export const metadata: Metadata = {
  title: "맥 앱",
  description: "역할별로 찾는 Mac 앱 — Develop, Design, Work, Productivity, System, Media",
};

interface Props {
  searchParams: Promise<{ category?: string; page?: string }>;
}

export default async function AppsPage({ searchParams }: Props) {
  const { category, page: pageStr } = await searchParams;
  const page = pageStr ? Number(pageStr) : 1;

  const [cats, result] = await Promise.all([
    getCategories(),
    getPosts({ categorySlug: category || undefined, page }),
  ]);
  const active = category ? cats.find((c) => c.slug === category) : null;

  return (
    <div className="md:flex md:gap-8">
      {/* 좌측: 역할 카테고리 필터 */}
      <aside className="md:w-56 shrink-0 mb-6 md:mb-0">
        <h1 className="text-2xl font-bold mb-4">맥 앱</h1>
        <nav className="flex md:flex-col gap-2 overflow-x-auto md:overflow-visible">
          <Link
            href="/apps"
            className={`badge whitespace-nowrap ${!category ? "bg-primary text-white" : "bg-surface-hover text-text-secondary"}`}
          >
            전체
          </Link>
          {cats.map((c) => (
            <Link
              key={c.slug}
              href={`/apps?category=${c.slug}`}
              className={`badge whitespace-nowrap ${active?.slug === c.slug ? "bg-primary text-white" : "bg-surface-hover text-text-secondary"}`}
            >
              {c.name} ({c.postCount})
            </Link>
          ))}
        </nav>
      </aside>

      {/* 우측: 글 목록 */}
      <section className="flex-1">
        <div className="mb-4">
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
          <p className="text-sm text-text-muted mt-1">게시글 {result.total}개</p>
        </div>

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
              basePath={category ? `/apps?category=${category}` : "/apps"}
            />
          </>
        )}
      </section>
    </div>
  );
}