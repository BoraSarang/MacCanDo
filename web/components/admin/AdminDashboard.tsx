// [FEATURE] 관리자 대시보드 — T-05
// 탭: 요약 통계 / 게시글별 통계 / 댓글 승인 / 시리즈 관리
"use client";

import { useState, useEffect } from "react";
import { logger } from "@/lib/logger";
import SeriesManager from "./SeriesManager";
import AdsManager from "./AdsManager";

interface DailyRow {
  date: string;
  views: number;
  clicks: number;
  comments: number;
  newUsers: number;
}

interface Summary {
  postCount: number;
  commentCount: number;
  pendingCommentCount: number;
  clickCount: number;
  userCount: number;
  totalViews: number;
  daily: DailyRow[];
}

interface PendingComment {
  id: string;
  content: string;
  createdAt: string;
  user: { name: string | null; email: string | null; image: string | null };
  post: { slug: string; title: string };
}

interface PostStat {
  id: string;
  title: string;
  slug: string;
  viewCount: number;
  status: string;
  publishedAt: string | null;
  excerpt: string | null;
  seoMeta: { title?: string; description?: string; tags?: string[] } | null;
  _count: { comments: number; downloadEvents: number };
}

type Tab = "summary" | "posts" | "comments" | "series" | "ads";

export default function AdminDashboard() {
  const [tab, setTab] = useState<Tab>("summary");
  const [summary, setSummary] = useState<Summary | null>(null);
  const [posts, setPosts] = useState<PostStat[]>([]);
  const [pending, setPending] = useState<PendingComment[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    logger.info("Admin", "대시보드 표시됨");
    Promise.all([
      fetch("/api/admin/stats").then((r) => r.json()),
      fetch("/api/admin/posts").then((r) => r.json()),
      fetch("/api/admin/comments").then((r) => r.json()),
    ])
      .then(([s, p, c]) => {
        if (s.ok) setSummary(s.data);
        if (p.ok) setPosts(p.data);
        if (c.ok) setPending(c.data);
        if (!s.ok || !p.ok || !c.ok) setError("관리자 권한이 필요합니다.");
      })
      .catch(() => setError("데이터를 불러오지 못했습니다."));
  }, []);

  const setStatus = async (id: string, status: "APPROVED" | "SPAM") => {
    const res = await fetch(`/api/admin/comments/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ status }),
    });
    const j = await res.json();
    if (j.ok) {
      setPending((prev) => prev.filter((c) => c.id !== id));
      logger.info("Admin", `댓글 승인 처리 (${id}, ${status})`);
    }
  };

  const tabBtn = (t: Tab, label: string) => (
    <button
      onClick={() => setTab(t)}
      className={`px-4 py-2 rounded-lg text-sm ${
        tab === t ? "bg-primary text-white" : "bg-surface-hover text-text-secondary"
      }`}
    >
      {label}
    </button>
  );

  const fmtDate = (d: string | null) =>
    d ? new Intl.DateTimeFormat("ko-KR", { dateStyle: "short" }).format(new Date(d)) : "-";

  if (error) {
    return <p className="text-danger">{error}</p>;
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">관리자 대시보드</h1>

      <div className="flex gap-2 mb-6">
        {tabBtn("summary", "요약 통계")}
        {tabBtn("posts", "게시글별 통계")}
        {tabBtn("comments", `댓글 승인${pending.length ? ` (${pending.length})` : ""}`)}
        {tabBtn("series", "시리즈")}
        {tabBtn("ads", "광고")}
      </div>

      {tab === "series" && <SeriesManager />}
      {tab === "ads" && <AdsManager />}

      {tab === "summary" && summary && (
        <div>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3 mb-6">
            {[
              { label: "게시글", value: summary.postCount },
              { label: "전체 조회수", value: summary.totalViews },
              { label: "댓글", value: summary.commentCount },
              { label: "승인 대기", value: summary.pendingCommentCount },
              { label: "다운로드 클릭", value: summary.clickCount },
              { label: "사용자", value: summary.userCount },
            ].map((s) => (
              <div key={s.label} className="border border-border rounded-xl p-4 text-center">
                <div className="text-2xl font-bold">{s.value.toLocaleString()}</div>
                <div className="text-xs text-text-muted mt-1">{s.label}</div>
              </div>
            ))}
          </div>

          <h2 className="text-lg font-bold mb-3">최근 14일</h2>
          <div className="border border-border rounded-xl overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-surface">
                <tr>
                  <th className="p-2 text-left">날짜</th>
                  <th className="p-2 text-right">조회</th>
                  <th className="p-2 text-right">클릭</th>
                  <th className="p-2 text-right">댓글</th>
                  <th className="p-2 text-right">신규 사용자</th>
                </tr>
              </thead>
              <tbody>
                {summary.daily.map((d) => (
                  <tr key={d.date} className="border-t border-border">
                    <td className="p-2">{fmtDate(d.date)}</td>
                    <td className="p-2 text-right">{d.views}</td>
                    <td className="p-2 text-right">{d.clicks}</td>
                    <td className="p-2 text-right">{d.comments}</td>
                    <td className="p-2 text-right">{d.newUsers}</td>
                  </tr>
                ))}
                {summary.daily.length === 0 && (
                  <tr>
                    <td colSpan={5} className="p-4 text-center text-text-muted">
                      아직 일별 통계가 없습니다.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {tab === "posts" && (
        <div className="border border-border rounded-xl overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-surface">
              <tr>
                <th className="p-2 text-left">게시글</th>
                <th className="p-2 text-center">SEO</th>
                <th className="p-2 text-right">조회</th>
                <th className="p-2 text-right">다운로드</th>
                <th className="p-2 text-right">댓글</th>
                <th className="p-2 text-right">상태</th>
              </tr>
            </thead>
            <tbody>
              {posts.map((p) => (
                <tr key={p.id} className="border-t border-border">
                  <td className="p-2">
                    <div className="font-medium">{p.title}</div>
                    <div className="text-xs text-text-muted">{p.slug}</div>
                  </td>
                  <td className="p-2 text-center">
                    {p.seoMeta ? (
                      <span
                        title={
                          [
                            p.seoMeta.title ? `SEO 제목: ${p.seoMeta.title}` : null,
                            p.seoMeta.description ? `설명: ${p.seoMeta.description}` : null,
                            p.seoMeta.tags?.length ? `키워드: ${p.seoMeta.tags.join(", ")}` : null,
                            `적용: ${p.seoMeta.title || p.seoMeta.description || "확인"}`,
                          ]
                            .filter(Boolean)
                            .join("\n")
                        }
                        className="cursor-help text-sm"
                      >
                        <span className="badge badge-success">AI</span>
                      </span>
                    ) : p.excerpt ? (
                      <span title={p.excerpt} className="cursor-help text-sm text-text-muted">
                        요약
                      </span>
                    ) : (
                      <span className="text-text-muted">—</span>
                    )}
                  </td>
                  <td className="p-2 text-right">{p.viewCount}</td>
                  <td className="p-2 text-right">{p._count.downloadEvents}</td>
                  <td className="p-2 text-right">{p._count.comments}</td>
                  <td className="p-2 text-right">
                    <span
                      className={`px-2 py-0.5 rounded text-xs ${
                        p.status === "PUBLISHED" ? "bg-success-soft text-success" : "bg-surface-hover text-text-muted"
                      }`}
                    >
                      {p.status}
                    </span>
                  </td>
                </tr>
              ))}
              {posts.length === 0 && (
                <tr>
                  <td colSpan={6} className="p-4 text-center text-text-muted">
                    게시글이 없습니다.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {tab === "comments" && (
        <div className="space-y-3">
          {pending.length === 0 ? (
            <p className="text-text-muted text-center py-8">승인 대기 댓글이 없습니다.</p>
          ) : (
            pending.map((c) => (
              <div key={c.id} className="border border-border rounded-xl p-4">
                <div className="flex items-center gap-2 mb-1">
                  {c.user.image && (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={c.user.image} alt="" className="w-6 h-6 rounded-full" />
                  )}
                  <span className="text-sm font-medium">{c.user.name ?? "익명"}</span>
                  <span className="text-xs text-text-muted">{c.user.email}</span>
                  <span className="text-xs text-text-muted ml-auto">{fmtDate(c.createdAt)}</span>
                </div>
                <p className="text-sm whitespace-pre-wrap mb-2">{c.content}</p>
                <div className="text-xs text-text-muted mb-3">
                  게시글: {c.post.title} ({c.post.slug})
                </div>
                <div className="flex gap-2">
                  <button
                    onClick={() => setStatus(c.id, "APPROVED")}
                    className="px-3 py-1 rounded-lg bg-success text-white text-xs"
                  >
                    승인
                  </button>
                  <button
                    onClick={() => setStatus(c.id, "SPAM")}
                    className="px-3 py-1 rounded-lg bg-danger text-white text-xs"
                  >
                    스팸 처리
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      )}
    </div>
  );
}