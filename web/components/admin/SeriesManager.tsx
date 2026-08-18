// [FEATURE] 관리자 시리즈 관리 — 시리즈 목록/생성/수정/삭제 + 글 추가/제거 + ↑↓ 순서 변경
"use client";

import { useState, useEffect, useCallback } from "react";
import { logger } from "@/lib/logger";

interface SeriesPost {
  id: string;
  title: string;
  slug: string;
  status: string;
  seriesOrder: number;
  publishedAt: string | null;
}

interface SeriesItem {
  id: string;
  title: string;
  description: string | null;
  createdAt: string;
  posts: SeriesPost[];
}

interface LoosePost {
  id: string;
  title: string;
  slug: string;
  status: string;
  updatedAt: string;
}

export default function SeriesManager() {
  const [series, setSeries] = useState<SeriesItem[]>([]);
  const [loosePosts, setLoosePosts] = useState<LoosePost[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [newTitle, setNewTitle] = useState("");
  const [newDesc, setNewDesc] = useState("");
  const [picked, setPicked] = useState<string[]>([]);

  const reload = useCallback(async () => {
    const r = await fetch("/api/admin/series");
    const j = await r.json();
    if (j.ok) {
      setSeries(j.data.series);
      setLoosePosts(j.data.loosePosts);
      setSelectedId((prev) => (prev && j.data.series.some((s: SeriesItem) => s.id === prev) ? prev : j.data.series[0]?.id ?? null));
    } else {
      setError("시리즈 목록을 불러오지 못했습니다.");
    }
  }, []);

  useEffect(() => {
    logger.info("Admin", "시리즈 탭 표시됨");
    reload();
  }, [reload]);

  const selected = series.find((s) => s.id === selectedId) ?? null;

  const create = async () => {
    if (!newTitle.trim()) return;
    const r = await fetch("/api/admin/series", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: newTitle, description: newDesc }),
    });
    const j = await r.json();
    if (j.ok) {
      logger.info("Admin", `시리즈 생성 (${newTitle})`);
      setNewTitle("");
      setNewDesc("");
      reload();
    }
  };

  const rename = async () => {
    if (!selected) return;
    const title = window.prompt("시리즈 제목", selected.title);
    if (title === null) return;
    const desc = window.prompt("시리즈 설명 (비우면 없음)", selected.description ?? "");
    if (desc === null) return;
    const r = await fetch(`/api/admin/series/${selected.id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title, description: desc }),
    });
    const j = await r.json();
    if (j.ok) reload();
  };

  const remove = async () => {
    if (!selected) return;
    if (!window.confirm(`시리즈 '${selected.title}'를 삭제할까요? (글은 유지됩니다)`)) return;
    const r = await fetch(`/api/admin/series/${selected.id}`, { method: "DELETE" });
    const j = await r.json();
    if (j.ok) {
      logger.info("Admin", `시리즈 삭제 (${selected.id})`);
      reload();
    }
  };

  const addPicked = async () => {
    if (!selected || picked.length === 0) return;
    const r = await fetch(`/api/admin/series/${selected.id}/posts`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ postIds: picked }),
    });
    const j = await r.json();
    if (j.ok) {
      logger.info("Admin", `시리즈 글 추가 (${picked.length}개 → ${selected.id})`);
      setPicked([]);
      reload();
    }
  };

  // 순서 저장 — 배열 순서 = 1편, 2편...
  const saveOrder = async (ordered: string[]) => {
    if (!selected) return;
    const r = await fetch(`/api/admin/series/${selected.id}/posts`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ postIds: ordered }),
    });
    const j = await r.json();
    if (j.ok) {
      logger.info("Admin", `시리즈 순서 저장 (${selected.id}, ${ordered.length}개)`);
      reload();
    }
  };

  const movePost = (idx: number, dir: -1 | 1) => {
    if (!selected) return;
    const ordered = selected.posts.map((p) => p.id);
    const to = idx + dir;
    if (to < 0 || to >= ordered.length) return;
    [ordered[idx], ordered[to]] = [ordered[to], ordered[idx]];
    saveOrder(ordered);
  };

  const removePost = async (postId: string) => {
    if (!selected) return;
    const r = await fetch(`/api/admin/series/${selected.id}/posts?postId=${postId}`, { method: "DELETE" });
    const j = await r.json();
    if (j.ok) reload();
  };

  if (error) return <p className="text-danger">{error}</p>;

  return (
    <div>
      <div className="flex flex-wrap gap-2 mb-6">
        {series.map((s) => (
          <button
            key={s.id}
            onClick={() => setSelectedId(s.id)}
            className={`px-4 py-2 rounded-lg text-sm border ${
              selectedId === s.id
                ? "bg-primary text-white border-primary"
                : "bg-surface-hover text-text-secondary border-transparent"
            }`}
          >
            {s.title} ({s.posts.length})
          </button>
        ))}
      </div>

      {/* 새 시리즈 */}
      <div className="border border-border rounded-xl p-4 mb-6">
        <h3 className="font-bold mb-2">＋ 새 시리즈</h3>
        <div className="flex flex-col md:flex-row gap-2">
          <input
            value={newTitle}
            onChange={(e) => setNewTitle(e.target.value)}
            placeholder="시리즈 제목 (예: CleanMyMac 완벽 가이드)"
            className="input flex-1"
          />
          <input
            value={newDesc}
            onChange={(e) => setNewDesc(e.target.value)}
            placeholder="설명 (선택)"
            className="input flex-1"
          />
          <button onClick={create} className="btn-primary shrink-0" disabled={!newTitle.trim()}>
            만들기
          </button>
        </div>
      </div>

      {selected && (
        <div className="border border-border rounded-xl p-4 mb-6">
          <div className="flex items-center gap-2 mb-3">
            <h3 className="font-bold text-lg">{selected.title}</h3>
            {selected.description && (
              <span className="text-sm text-text-secondary">{selected.description}</span>
            )}
            <div className="ml-auto flex gap-2">
              <button onClick={rename} className="btn-ghost text-sm">
                수정
              </button>
              <button onClick={remove} className="btn-ghost text-sm text-danger">
                삭제
              </button>
            </div>
          </div>
          <p className="text-xs text-text-muted mb-2">
            순서 = 편 번호 (1편, 2편, 3편...) — ↑↓로 변경하면 즉시 저장됩니다.
          </p>
          {selected.posts.length === 0 ? (
            <p className="text-text-muted text-sm py-4 text-center">아직 글이 없습니다. 아래에서 추가하세요.</p>
          ) : (
            <ol className="space-y-1">
              {selected.posts.map((p, idx) => (
                <li key={p.id} className="flex items-center gap-2 py-1.5 px-2 rounded-lg hover:bg-surface">
                  <span className="badge bg-primary-soft text-primary shrink-0">{p.seriesOrder}편</span>
                  <span className="truncate">{p.title}</span>
                  {p.status === "DRAFT" && (
                    <span className="badge bg-warning-soft text-warning shrink-0">초안</span>
                  )}
                  <span className="ml-auto flex gap-1 shrink-0">
                    <button
                      onClick={() => movePost(idx, -1)}
                      disabled={idx === 0}
                      className="px-2 py-0.5 rounded border border-border hover:bg-surface-hover disabled:opacity-30"
                      title="앞으로"
                    >
                      ↑
                    </button>
                    <button
                      onClick={() => movePost(idx, 1)}
                      disabled={idx === selected.posts.length - 1}
                      className="px-2 py-0.5 rounded border border-border hover:bg-surface-hover disabled:opacity-30"
                      title="뒤로"
                    >
                      ↓
                    </button>
                    <button
                      onClick={() => removePost(p.id)}
                      className="px-2 py-0.5 rounded border border-border text-danger hover:bg-surface-hover"
                      title="시리즈에서 제거"
                    >
                      ✕
                    </button>
                  </span>
                </li>
              ))}
            </ol>
          )}

          {/* 시리즈 없는 글 추가 */}
          <div className="mt-4 pt-4 border-t border-border">
            <h4 className="text-sm font-semibold mb-2">시리즈 없는 글 → 추가</h4>
            {loosePosts.length === 0 ? (
              <p className="text-xs text-text-muted">시리즈 없는 글이 없습니다.</p>
            ) : (
              <>
                <div className="flex flex-wrap gap-1.5 max-h-32 overflow-y-auto mb-2">
                  {loosePosts.map((p) => (
                    <label
                      key={p.id}
                      className={`px-2 py-1 rounded-lg border text-xs cursor-pointer select-none ${
                        picked.includes(p.id)
                          ? "border-primary bg-primary-soft text-primary"
                          : "border-border hover:bg-surface-hover"
                      }`}
                    >
                      <input
                        type="checkbox"
                        className="hidden"
                        checked={picked.includes(p.id)}
                        onChange={() =>
                          setPicked((prev) =>
                            prev.includes(p.id) ? prev.filter((x) => x !== p.id) : [...prev, p.id]
                          )
                        }
                      />
                      {p.title}
                    </label>
                  ))}
                </div>
                <button onClick={addPicked} className="btn-primary text-sm" disabled={picked.length === 0}>
                  선택 {picked.length}개 시리즈에 추가
                </button>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}