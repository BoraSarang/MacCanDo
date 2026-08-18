// [FEATURE] 시리즈 목록 — 게시글 하단 (사용자 요청: 1편/2편/3편 + 현재 표시 + 클릭 이동)
import Link from "next/link";

export interface SeriesListData {
  id: string;
  title: string;
  posts: { id: string; title: string; slug: string; seriesOrder: number }[];
}

export default function SeriesList({
  series,
  currentId,
}: {
  series: SeriesListData | null;
  currentId: string;
}) {
  if (!series || series.posts.length === 0) return null;

  return (
    <section className="mt-10 card p-6">
      <h2 className="font-bold text-lg mb-4">{series.title}</h2>
      <ol className="space-y-1">
        {series.posts.map((p) => {
          const isCurrent = p.id === currentId;
          return (
            <li key={p.id}>
              {isCurrent ? (
                <span className="flex items-center gap-2 py-2 px-3 rounded-lg bg-primary-soft border border-primary/40 font-semibold text-primary">
                  <span className="inline-block w-2 h-2 rounded-full bg-primary animate-pulse" />
                  {p.seriesOrder}편 · {p.title}
                  <span className="text-xs font-normal bg-primary text-white px-2 py-0.5 rounded-full">
                    보고 있는 글
                  </span>
                </span>
              ) : (
                <Link
                  href={`/post/${p.slug}`}
                  className="block py-2 px-3 rounded-lg hover:bg-bg-soft hover:border-primary/30 border border-transparent transition-all"
                >
                  <span className="text-text-muted mr-2">{p.seriesOrder}편</span>
                  {p.title}
                </Link>
              )}
            </li>
          );
        })}
      </ol>
    </section>
  );
}
