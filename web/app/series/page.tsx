// [FEATURE] 시리즈 모아보기 — 모든 시리즈 (제목 + 설명 + 글 리스트, 순서대로)
import Link from "next/link";
import { getSeriesOverview } from "@/lib/series";

export const revalidate = 60;

export default async function SeriesPage() {
  const series = await getSeriesOverview();

  return (
    <div className="max-w-3xl mx-auto">
      <header className="text-center py-10 mb-6">
        <h1 className="text-3xl font-bold mb-2">📚 시리즈</h1>
        <p className="text-text-secondary">여러 편으로 나뉜 가이드를 한곳에서 모아보세요.</p>
      </header>

      {series.length === 0 ? (
        <p className="text-text-muted text-center py-16">아직 시리즈가 없습니다.</p>
      ) : (
        <div className="space-y-6">
          {series.map((s) => (
            <section key={s.id} className="card p-6">
              <Link href={`/series/${s.id}`} className="group">
                <h2 className="text-xl font-bold group-hover:text-primary transition-colors">
                  📚 {s.title}
                </h2>
              </Link>
              {s.description && (
                <p className="text-sm text-text-secondary mt-1 mb-4">{s.description}</p>
              )}
              <ol className="space-y-1 mt-4">
                {s.posts.map((p) => (
                  <li key={p.id}>
                    <Link
                      href={`/post/${p.slug}`}
                      className="flex items-center gap-3 py-2 px-3 rounded-lg hover:bg-bg-soft hover:border-primary/30 border border-transparent transition-all"
                    >
                      <span className="badge bg-primary-soft text-primary shrink-0">
                        {p.seriesOrder}편
                      </span>
                      <span className="font-medium">{p.title}</span>
                      {p.thumbnailUrl ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img
                          src={p.thumbnailUrl}
                          alt=""
                          className="w-16 h-10 object-cover rounded ml-auto"
                        />
                      ) : null}
                    </Link>
                  </li>
                ))}
              </ol>
            </section>
          ))}
        </div>
      )}
    </div>
  );
}