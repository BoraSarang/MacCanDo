// [FEATURE] 태그별 게시글 목록 — 자유 생성 태그 모아보기
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { getPosts, getTags } from "@/lib/posts";
import PostCard from "@/components/PostCard";
import Pagination from "@/components/Pagination";
import SortSelect from "@/components/SortSelect";

export const revalidate = 60;

interface Props {
  params: Promise<{ slug: string }>;
  searchParams: Promise<{ page?: string; sort?: string }>;
}

// Next가 params를 디코딩하지 않는 케이스 대응 (한글 slug — %EC%95%A0%ED%94%8C 형태로 도착)
function decodeSlug(raw: string): string {
  try {
    return decodeURIComponent(raw);
  } catch {
    return raw;
  }
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug: raw } = await params;
  const slug = decodeSlug(raw);
  const tags = await getTags();
  const tag = tags.find((t) => t.slug === slug);
  return {
    title: tag ? `#${tag.name}` : "태그",
    description: `MacCanDo #${tag?.name ?? slug} 태그 게시글 목록`,
  };
}

export default async function TagPage({ params, searchParams }: Props) {
  const { slug: raw } = await params;
  const slug = decodeSlug(raw);
  const { page: pageStr, sort: sortStr } = await searchParams;
  const page = pageStr ? Number(pageStr) : 1;
  const sort = sortStr === "views" ? ("views" as const) : ("latest" as const);

  const tags = await getTags();
  const tag = tags.find((t) => t.slug === slug);
  if (!tag) notFound();

  const result = await getPosts({ tagSlug: slug, page, sort });

  return (
    <div>
      <div className="flex items-end justify-between mb-2">
        <h1 className="text-2xl font-bold">#{tag.name}</h1>
        <SortSelect value={sort} basePath={`/tag/${slug}`} />
      </div>
      <p className="text-sm text-text-muted mb-6">게시글 {result.total}개</p>
      {result.items.length === 0 ? (
        <p className="text-text-muted text-center py-10">이 태그의 게시글이 없습니다.</p>
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {result.items.map((p) => (
              <PostCard key={p.id} post={p} />
            ))}
          </div>
          <Pagination page={result.page} totalPages={result.totalPages} basePath={`/tag/${slug}${sort === "views" ? "?sort=views" : ""}`} />
        </>
      )}
    </div>
  );
}