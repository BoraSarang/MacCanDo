// [FEATURE] 홈 추천 게시글 — 광고 슬롯 (T-11)
// 관리자 지정(featuredOrder) 우선 + 모자라면 조회수 top으로 자동 채움
// 대형 카드 1 + 소형 카드 2 (웨일 확장 스토어 추천 배너 스타일)
import Link from "next/link";

type FeaturedPost = {
  id: string;
  slug: string;
  title: string;
  excerpt: string | null;
  thumbnailUrl: string | null;
  publishedAt: Date | null;
  viewCount: number;
  categories: { category: { name: string; slug: string } }[];
};

function formatDate(d: Date | null) {
  if (!d) return "";
  return new Intl.DateTimeFormat("ko-KR", { year: "numeric", month: "short", day: "numeric" }).format(d);
}

export default function FeaturedPosts({ posts }: { posts: FeaturedPost[] }) {
  if (posts.length === 0) return null;
  const [main, ...rest] = posts;

  return (
    <section className="mb-10">
      <div className="flex items-end justify-between mb-4">
        <h2 className="text-xl font-bold">추천 게시글</h2>
        <Link href="/apps" className="text-sm text-primary hover:underline">
          모든 게시글 →
        </Link>
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* 대형 카드 */}
        <Link href={`/post/${main.slug}`} className="group card overflow-hidden lg:col-span-2 hover:border-primary/50 hover:shadow-md transition-all">
          <div className="relative aspect-[21/9] bg-surface-hover">
            {main.thumbnailUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={main.thumbnailUrl}
                alt={main.title}
                className="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
              />
            ) : (
              <div className="absolute inset-0 flex items-center justify-center text-5xl font-bold text-primary/15">
                {main.title.slice(0, 1)}
              </div>
            )}
          </div>
          <div className="p-4">
            <div className="flex gap-1.5 flex-wrap mb-1.5">
              {main.categories.map((c) => (
                <span key={c.category.slug} className="text-[11px] px-2 py-0.5 rounded-full bg-primary/10 text-primary">
                  {c.category.name}
                </span>
              ))}
            </div>
            <div className="text-lg font-bold group-hover:text-primary transition-colors line-clamp-1">{main.title}</div>
            {main.excerpt && <p className="text-sm text-text-muted mt-1 line-clamp-2">{main.excerpt}</p>}
            <div className="text-xs text-text-muted mt-2">{formatDate(main.publishedAt)} · 조회 {main.viewCount.toLocaleString()}</div>
          </div>
        </Link>

        {/* 소형 카드 2 */}
        <div className="grid gap-4">
          {rest.map((p) => (
            <Link key={p.id} href={`/post/${p.slug}`} className="group card overflow-hidden hover:border-primary/50 hover:shadow-md transition-all">
              <div className="grid grid-cols-[112px_1fr] h-full">
                <div className="relative bg-surface-hover">
                  {p.thumbnailUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={p.thumbnailUrl} alt={p.title} className="absolute inset-0 w-full h-full object-cover" />
                  ) : (
                    <div className="absolute inset-0 flex items-center justify-center text-2xl font-bold text-primary/15">
                      {p.title.slice(0, 1)}
                    </div>
                  )}
                </div>
                <div className="p-3 flex flex-col justify-center min-w-0">
                  <div className="font-semibold text-sm group-hover:text-primary transition-colors line-clamp-2">{p.title}</div>
                  <div className="text-[11px] text-text-muted mt-1.5">
                    {formatDate(p.publishedAt)} · 조회 {p.viewCount.toLocaleString()}
                  </div>
                </div>
              </div>
            </Link>
          ))}
        </div>
      </div>
    </section>
  );
}