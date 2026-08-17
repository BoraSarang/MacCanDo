// [FEATURE] 홈 — 시리즈 배너(광고 슬롯) → 추천 → 최근 게시글 → 역할별 탐색 (T-11)
import Link from "next/link";
import { getRecentPosts, getCategories, getFeaturedPosts } from "@/lib/posts";
import { getSeriesBanner } from "@/lib/series";
import PostCard from "@/components/PostCard";
import SeriesBanner from "@/components/SeriesBanner";
import FeaturedPosts from "@/components/FeaturedPosts";

export const revalidate = 60;

export default async function HomePage() {
  const [featured, series, posts, categories] = await Promise.all([
    getFeaturedPosts(3),
    getSeriesBanner(4),
    getRecentPosts(6),
    getCategories(),
  ]);

  return (
    <div>
      {/* 히어로 */}
      <section className="text-center py-12 mb-8">
        <h1 className="text-3xl md:text-4xl font-bold mb-3">
          맥으로{" "}
          <span className="bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">
            이것도 할 수 있다
          </span>
        </h1>
        <p className="text-text-secondary max-w-2xl mx-auto">
          유용한 Mac 프로그램 소개, 꿀팁 가이드, 최신 소식까지 — MacCanDo에서 확인하세요.
        </p>
      </section>

      {/* 시리즈 배너 — 광고 슬롯 (T-11) */}
      <SeriesBanner series={series} />

      {/* 추천 게시글 — 광고 슬롯 (T-11) */}
      <FeaturedPosts posts={featured} />

      {/* 최신 게시글 */}
      <section className="mb-10">
        <div className="flex items-end justify-between mb-4">
          <h2 className="text-xl font-bold">최근 게시글</h2>
          <Link href="/apps" className="text-sm text-primary hover:underline">
            모든 게시글 →
          </Link>
        </div>
        {posts.items.length === 0 ? (
          <p className="text-text-muted text-center py-10">아직 게시글이 없습니다.</p>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {posts.items.map((p) => (
              <PostCard key={p.id} post={p} />
            ))}
          </div>
        )}
      </section>

      {/* 카테고리 — 역할 기반 */}
      <section>
        <h2 className="text-xl font-bold mb-4">역할별 탐색</h2>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
          {categories.filter((c) => c.postCount > 0).map((c) => (
            <Link
              key={c.slug}
              href={`/category/${c.slug}`}
              className="card p-4 hover:border-primary/50 hover:shadow-md transition-all"
            >
              <div className="font-semibold flex items-center gap-2">
                <span aria-hidden className="text-lg">{c.icon ?? "📁"}</span>
                {c.name}
              </div>
              {c.description && <div className="text-xs text-text-muted mt-1">{c.description}</div>}
              <div className="text-xs text-text-muted mt-2">게시글 {c.postCount}개</div>
            </Link>
          ))}
        </div>
      </section>

      {/* 최신 게시글 */}
      <section>
        <h2 className="text-xl font-bold mb-4">최신 게시글</h2>
        {posts.items.length === 0 ? (
          <p className="text-text-muted text-center py-10">아직 게시글이 없습니다.</p>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {posts.items.map((p) => (
              <PostCard key={p.id} post={p} />
            ))}
          </div>
        )}
      </section>
    </div>
  );
}