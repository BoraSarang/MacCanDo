// [FEATURE] 카테고리별 게시글 목록 — T-03
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { getPosts, getCategories } from "@/lib/posts";
import PostCard from "@/components/PostCard";
import Pagination from "@/components/Pagination";
import SortSelect from "@/components/SortSelect";

export const revalidate = 60;

interface Props {
  params: Promise<{ slug: string }>;
  searchParams: Promise<{ page?: string; sort?: string }>;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const cats = await getCategories();
  const cat = cats.find((c) => c.slug === slug);
  return {
    title: cat ? cat.name : "카테고리",
    description: cat?.description
      ? `MacCanDo ${cat.name} — ${cat.description} 게시글 목록`
      : `MacCanDo ${cat?.name ?? slug} 카테고리 게시글 목록`,
  };
}

export default async function CategoryPage({ params, searchParams }: Props) {
  const { slug } = await params;
  const { page: pageStr, sort: sortStr } = await searchParams;
  const page = pageStr ? Number(pageStr) : 1;
  const sort = sortStr === "views" ? ("views" as const) : ("latest" as const);

  const cats = await getCategories();
  const cat = cats.find((c) => c.slug === slug);
  if (!cat) notFound();

  const result = await getPosts({ categorySlug: slug, page, sort });

  return (
    <div>
      <div className="flex items-end justify-between mb-2">
        <h1 className="text-2xl font-bold">{cat.name}</h1>
        <SortSelect value={sort} basePath={`/category/${slug}`} />
      </div>
      {cat.description && <p className="text-sm text-text-secondary mb-2">{cat.description}</p>}
      <p className="text-sm text-text-muted mb-6">게시글 {result.total}개</p>

      {result.items.length === 0 ? (
        <p className="text-text-muted text-center py-10">게시글이 없습니다.</p>
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {result.items.map((p) => (
              <PostCard key={p.id} post={p} />
            ))}
          </div>
          <Pagination page={result.page} totalPages={result.totalPages} basePath={`/category/${slug}${sort === "views" ? "?sort=views" : ""}`} />
        </>
      )}
    </div>
  );
}