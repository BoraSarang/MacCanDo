// [FEATURE] 맥 소식 목록 — contentType=NEWS
import type { Metadata } from "next";
import { getPosts } from "@/lib/posts";
import PostCard from "@/components/PostCard";
import Pagination from "@/components/Pagination";
import SortSelect from "@/components/SortSelect";

export const revalidate = 60;

export const metadata: Metadata = {
  title: "맥 소식",
  description: "Mac 관련 최신 소식과 업데이트",
};

interface Props {
  searchParams: Promise<{ page?: string; sort?: string }>;
}

export default async function NewsPage({ searchParams }: Props) {
  const { page: pageStr, sort: sortStr } = await searchParams;
  const page = pageStr ? Number(pageStr) : 1;
  const sort = sortStr === "views" ? ("views" as const) : ("latest" as const);
  const result = await getPosts({ contentType: "NEWS", page, sort });

  return (
    <div>
      <div className="flex items-end justify-between mb-2">
        <h1 className="text-2xl font-bold">맥 소식</h1>
        <SortSelect value={sort} basePath="/news" />
      </div>
      <p className="text-sm text-text-muted mb-6">Mac 관련 최신 소식 — 게시글 {result.total}개</p>
      {result.items.length === 0 ? (
        <p className="text-text-muted text-center py-10">아직 소식이 없습니다.</p>
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {result.items.map((p) => (
              <PostCard key={p.id} post={p} />
            ))}
          </div>
          <Pagination page={result.page} totalPages={result.totalPages} basePath="/news" />
        </>
      )}
    </div>
  );
}