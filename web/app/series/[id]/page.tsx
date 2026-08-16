// [FEATURE] 개별 시리즈 모아보기 — 제목 + 설명 + 글 목록 (순서대로, 발행만)
import Link from "next/link";
import { notFound } from "next/navigation";
import { getSeriesById } from "@/lib/series";

export const revalidate = 60;

export default async function SeriesDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const series = await getSeriesById(id);
  if (!series) notFound();

  return (
    <div className="max-w-3xl mx-auto">
      <header className="py-10 mb-6">
        <Link href="/series" className="text-sm text-text-muted hover:text-primary transition-colors">
          ← 모든 시리즈
        </Link>
        <h1 className="text-3xl font-bold mt-2 mb-2">📚 {series.title}</h1>
        {series.description && <p className="text-text-secondary">{series.description}</p>}
      </header>

      <ol className="space-y-3">
        {series.posts.map((p) => (
          <li key={p.id}>
            <Link
              href={`/post/${p.slug}`}
              className="card p-4 flex items-center gap-4 hover:border-primary/50 hover:shadow-md transition-all"
            >
              {p.thumbnailUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={p.thumbnailUrl}
                  alt=""
                  className="w-24 h-16 object-cover rounded-lg shrink-0"
                />
              ) : (
                <div className="w-24 h-16 rounded-lg bg-bg-soft shrink-0 flex items-center justify-center text-2xl">
                  📄
                </div>
              )}
              <div className="min-w-0">
                <div className="badge bg-primary-soft text-primary text-xs mb-1">{p.seriesOrder}편</div>
                <div className="font-semibold truncate">{p.title}</div>
                {p.excerpt && <div className="text-sm text-text-secondary line-clamp-1">{p.excerpt}</div>}
              </div>
            </Link>
          </li>
        ))}
      </ol>
    </div>
  );
}