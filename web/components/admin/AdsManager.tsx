// [FEATURE] 관리자 광고 탭 — 홈 광고 슬롯 관리 (T-11)
// 시리즈 배너 지정(★) + 추천 글 지정(★) — 지정 없으면 자동 채움(전체/조회수 top)
"use client";

import { useState, useEffect, useCallback } from "react";
import { logger } from "@/lib/logger";

interface SeriesRow {
  id: string;
  title: string;
  featuredOrder: number | null;
  posts: { id: string }[];
}

interface PostRow {
  id: string;
  title: string;
  slug: string;
  status: string;
  featuredOrder: number | null;
}

export default function AdsManager() {
  const [series, setSeries] = useState<SeriesRow[]>([]);
  const [posts, setPosts] = useState<PostRow[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const reload = useCallback(async () => {
    const [sr, pr] = await Promise.all([fetch("/api/admin/series"), fetch("/api/admin/posts?all=1")]);
    const sj = await sr.json();
    const pj = await pr.json();
    if (sj.ok && pj.ok) {
      setSeries(sj.data.series);
      setPosts(pj.data);
    } else {
      setError("광고 목록을 불러오지 못했습니다.");
    }
  }, []);

  useEffect(() => {
    logger.info("Admin", "광고 탭 표시됨 (시리즈 배너 + 추천)");
    reload();
  }, [reload]);

  const nextOrder = (list: { featuredOrder: number | null }[]) =>
    Math.max(0, ...list.map((x) => x.featuredOrder ?? 0)) + 1;

  const toggleSeriesBanner = async (s: SeriesRow) => {
    setBusy(`s-${s.id}`);
    const order = s.featuredOrder === null ? nextOrder(series) : null;
    const r = await fetch(`/api/admin/series/${s.id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ featuredOrder: order }),
    });
    const j = await r.json();
    if (j.ok) {
      logger.info("Admin", `시리즈 배너 ${order === null ? "해제" : `지정(${order})`} — ${s.title}`);
      reload();
    } else setError("배너 지정에 실패했습니다.");
    setBusy(null);
  };

  const toggleFeatured = async (p: PostRow) => {
    setBusy(`p-${p.id}`);
    const order = p.featuredOrder === null ? nextOrder(posts) : null;
    const r = await fetch(`/api/admin/posts/${p.id}/featured`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ order }),
    });
    const j = await r.json();
    if (j.ok) {
      logger.info("Admin", `추천 ${order === null ? "해제" : `지정(${order})`} — ${p.title}`);
      reload();
    } else setError("추천 지정에 실패했습니다.");
    setBusy(null);
  };

  const sortByOrder = <T extends { featuredOrder: number | null }>(list: T[]) =>
    [...list].sort((a, b) => (a.featuredOrder ?? 999) - (b.featuredOrder ?? 999));

  const bannerSeries = sortByOrder(series);
  const featuredPosts = sortByOrder(posts);

  return (
    <div className="grid md:grid-cols-2 gap-6">
      {error && <div className="text-red-500 text-sm md:col-span-2">{error}</div>}

      {/* 시리즈 배너 */}
      <section>
        <h3 className="font-bold mb-1">시리즈 배너 (홈 상단)</h3>
        <p className="text-xs text-text-muted mb-3">★ 지정 시 배너 먼저 노출, 미지정 시 전체 시리즈로 자동 채움</p>
        <ul className="border rounded-lg divide-y text-sm max-h-[420px] overflow-y-auto">
          {bannerSeries.map((s) => (
            <li key={s.id} className="flex items-center justify-between px-3 py-2">
              <div className="min-w-0">
                <div className="truncate font-medium">{s.title}</div>
                <div className="text-[11px] text-text-muted">{s.posts.length}개의 글</div>
              </div>
              <button
                onClick={() => toggleSeriesBanner(s)}
                disabled={busy === `s-${s.id}`}
                className={`shrink-0 px-2 py-1 rounded-lg text-xs font-semibold ${
                  s.featuredOrder !== null
                    ? "bg-amber-100 text-amber-700 hover:bg-amber-200"
                    : "bg-surface-hover text-text-muted hover:bg-surface-hover/70"
                }`}
                title={s.featuredOrder !== null ? `배너 지정됨 (순서 ${s.featuredOrder}) — 클릭 시 해제` : "배너에 지정"}
              >
                {s.featuredOrder !== null ? `★ ${s.featuredOrder}` : "☆ 지정"}
              </button>
            </li>
          ))}
          {series.length === 0 && <li className="px-3 py-4 text-center text-text-muted">시리즈가 없습니다.</li>}
        </ul>
      </section>

      {/* 추천 글 */}
      <section>
        <h3 className="font-bold mb-1">⭐ 추천 게시글 (홈 추천 섹션)</h3>
        <p className="text-xs text-text-muted mb-3">★ 지정 시 추천 노출 (최대 3개 권장), 미지정 시 조회수 top으로 자동 채움</p>
        <ul className="border rounded-lg divide-y text-sm max-h-[420px] overflow-y-auto">
          {featuredPosts.map((p) => (
            <li key={p.id} className="flex items-center justify-between px-3 py-2">
              <div className="min-w-0">
                <div className="truncate font-medium">
                  {p.title}
                  <span className="text-[11px] text-text-muted ml-1.5">
                    ({p.status === "PUBLISHED" ? "발행" : "초안"})
                  </span>
                </div>
              </div>
              <button
                onClick={() => toggleFeatured(p)}
                disabled={busy === `p-${p.id}`}
                className={`shrink-0 px-2 py-1 rounded-lg text-xs font-semibold ${
                  p.featuredOrder !== null
                    ? "bg-amber-100 text-amber-700 hover:bg-amber-200"
                    : "bg-surface-hover text-text-muted hover:bg-surface-hover/70"
                }`}
                title={p.featuredOrder !== null ? `추천 지정됨 (순서 ${p.featuredOrder}) — 클릭 시 해제` : "추천에 지정"}
              >
                {p.featuredOrder !== null ? `★ ${p.featuredOrder}` : "☆ 지정"}
              </button>
            </li>
          ))}
          {posts.length === 0 && <li className="px-3 py-4 text-center text-text-muted">게시글이 없습니다.</li>}
        </ul>
      </section>
    </div>
  );
}