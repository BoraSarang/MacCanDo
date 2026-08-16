// [FEATURE] 검색 결과 페이지 — T-03 (pg_trgm)
import type { Metadata } from "next";
import { getPosts } from "@/lib/posts";
import PostCard from "@/components/PostCard";
import Pagination from "@/components/Pagination";

interface Props {
  searchParams: Promise<{ q?: string; page?: string }>;
}

export async function generateMetadata({ searchParams }: Props): Promise<Metadata> {
  const { q } = await searchParams;
  return { title: q ? `"${q}" 검색 결과` : "검색" };
}

export default async function SearchPage({ searchParams }: Props) {
  const { q, page: pageStr } = await searchParams;
  const query = q ?? "";
  const page = pageStr ? Number(pageStr) : 1;

  const result = await getPosts({ query, page });

  return (
    <div>
      <h1 className="text-2xl font-bold mb-2">검색 결과</h1>
      <p className="text-sm text-text-muted mb-6">
        {query ? (
          <>
            &quot;{query}&quot; 검색 결과 {result.total}건
          </>
        ) : (
          "검색어를 입력해 주세요."
        )}
      </p>

      {query && result.items.length === 0 ? (
        <p className="text-text-muted text-center py-10">검색 결과가 없습니다.</p>
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {result.items.map((p) => (
              <PostCard key={p.id} post={p} />
            ))}
          </div>
          <Pagination page={result.page} totalPages={result.totalPages} basePath={`/search?q=${encodeURIComponent(query)}`} />
        </>
      )}
    </div>
  );
}