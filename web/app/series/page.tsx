// [FEATURE] 시리즈 모아보기 (허브) — 카드: 커버 + 제목 + 설명 1줄 + 편 수 (T-09)
// 상세/편 목록은 /series/[id] (랜딩)에서 — 역할 분리
import Link from "next/link";
import { getSeriesOverview } from "@/lib/series";

export const revalidate = 60;

const GRADIENTS = [
  "from-sky-500 to-blue-600",
  "from-emerald-500 to-teal-600",
  "from-amber-500 to-orange-600",
  "from-violet-500 to-purple-600",
  "from-rose-500 to-pink-600",
];

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
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
          {series.map((s, i) => (
            <Link
              key={s.id}
              href={`/series/${s.id}`}
              className="card overflow-hidden group hover:border-primary/40 hover:shadow-lg transition-all"
            >
              {s.imageUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={s.imageUrl}
                  alt={s.title}
                  className="w-full h-36 object-cover group-hover:scale-105 transition-transform duration-300"
                />
              ) : (
                <div
                  className={`w-full h-36 bg-gradient-to-br ${GRADIENTS[i % GRADIENTS.length]} flex items-center justify-center text-5xl`}
                >
                  📚
                </div>
              )}
              <div className="p-5">
                <div className="flex items-start justify-between gap-2">
                  <h2 className="text-lg font-bold group-hover:text-primary transition-colors">
                    {s.title}
                  </h2>
                  <span className="badge bg-primary-soft text-primary shrink-0">
                    {s.posts.length}개의 글
                  </span>
                </div>
                {s.description && (
                  <p className="text-sm text-text-secondary mt-2 line-clamp-2">{s.description}</p>
                )}
                <p className="text-xs text-text-muted mt-3 group-hover:text-primary transition-colors">
                  시리즈 보기 →
                </p>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}