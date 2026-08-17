// [FEATURE] 개별 시리즈 모아보기 (랜딩) — 커버 + 취지 + 편 목록 (T-09)
// 외부 공유/SEO 타깃: 취지(intro)로 "왜 읽어야 하는지" 전달
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { getSeriesById } from "@/lib/series";
import { renderMarkdown } from "@/lib/markdown";

export const revalidate = 60;

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params;
  const series = await getSeriesById(id);
  if (!series) return {};
  return {
    title: series.title,
    description:
      series.description ??
      `${series.posts.length}개의 글로 구성된 시리즈입니다. ${series.title}`,
  };
}

export default async function SeriesDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const series = await getSeriesById(id);
  if (!series) notFound();

  return (
    <div className="max-w-3xl mx-auto">
      <header className="mb-8">
        <Link href="/series" className="text-sm text-text-muted hover:text-primary transition-colors">
          ← 모든 시리즈
        </Link>
        {series.imageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={series.imageUrl} alt={series.title} className="w-full h-52 object-cover rounded-2xl mt-4" />
        ) : (
          <div className="w-full h-52 rounded-2xl bg-gradient-to-br from-sky-500 to-blue-600 flex items-center justify-center text-6xl mt-4">
            📚
          </div>
        )}
        <div className="mt-6">
          <div className="badge bg-primary-soft text-primary mb-2">
            {series.posts.length}개의 글 · 시리즈
          </div>
          <h1 className="text-3xl font-bold mb-2">{series.title}</h1>
          {series.description && <p className="text-text-secondary">{series.description}</p>}
        </div>
        {series.intro && (
          <div
            className="prose-sm text-text-secondary mt-4 leading-relaxed [&_h1]:text-lg [&_h2]:text-base [&_h3]:text-sm [&_h2]:font-bold [&_h3]:font-bold [&_ul]:list-disc [&_ul]:pl-5 [&_ol]:list-decimal [&_ol]:pl-5 [&_strong]:text-text-primary"
            dangerouslySetInnerHTML={{ __html: renderMarkdown(series.intro) }}
          />
        )}
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