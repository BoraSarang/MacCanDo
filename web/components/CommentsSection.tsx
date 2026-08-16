// [FEATURE] 댓글 섹션 — T-04
// 로그인(Google) 사용자만 작성 가능, honeypot 포함, 승인 대기 안내
"use client";

import { useState, useEffect, useCallback } from "react";
import { useSession, signIn } from "next-auth/react";
import { logger } from "@/lib/logger";

interface CommentUser {
  id: string;
  name: string | null;
  image: string | null;
}

interface Reply {
  id: string;
  content: string;
  createdAt: string;
  status: "PENDING" | "APPROVED" | "SPAM";
  userId: string | null;
  user: CommentUser;
}

interface CommentItem {
  id: string;
  content: string;
  createdAt: string;
  status: "PENDING" | "APPROVED" | "SPAM";
  userId: string | null;
  user: CommentUser;
  replies: Reply[];
}

export default function CommentsSection({ slug }: { slug: string }) {
  const { data: session, status } = useSession();
  const [comments, setComments] = useState<CommentItem[]>([]);
  const [content, setContent] = useState("");
  const [website, setWebsite] = useState(""); // honeypot
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [replyTo, setReplyTo] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editingContent, setEditingContent] = useState("");

  const load = useCallback(async () => {
    try {
      const res = await fetch(`/api/posts/${slug}/comments`);
      const j = await res.json();
      if (j.ok) setComments(j.data);
    } catch (e) {
      logger.error("Comments", `E-WEB-NET-1001 ${e instanceof Error ? e.message : e}`);
    }
  }, [slug]);

  useEffect(() => {
    let cancelled = false;
    logger.info("Comments", `목록 표시됨 (${slug})`);
    fetch(`/api/posts/${slug}/comments`)
      .then((r) => r.json())
      .then((j) => {
        if (!cancelled && j.ok) setComments(j.data);
      })
      .catch((e) => logger.error("Comments", `E-WEB-NET-1001 ${e instanceof Error ? e.message : e}`));
    return () => {
      cancelled = true;
    };
  }, [slug]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!content.trim()) return;

    setSubmitting(true);
    setMessage(null);
    try {
      const res = await fetch(`/api/posts/${slug}/comments`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ content, website, parentId: replyTo ?? undefined }),
      });
      const j = await res.json();
      if (j.ok) {
        setContent("");
        setReplyTo(null);
        setMessage("댓글이 등록되었습니다. 관리자 승인 후 표시됩니다.");
        logger.info("Comments", `작성 완료 (${slug})`);
        load();
      } else {
        setMessage(j.error?.message ?? "등록에 실패했습니다. 잠시 후 다시 시도해 주세요.");
        logger.error("Comments", `${j.error?.code ?? "E-WEB-NET-1001"} 등록 실패`);
      }
    } catch {
      setMessage("네트워크 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.");
    } finally {
      setSubmitting(false);
    }
  };

  const fmt = (d: string) => new Intl.DateTimeFormat("ko-KR", { dateStyle: "medium" }).format(new Date(d));

  // 댓글 수정 (본인 + PENDING)
  const saveEdit = async (id: string) => {
    if (!editingContent.trim()) return;
    setSubmitting(true);
    try {
      const res = await fetch(`/api/posts/${slug}/comments/${id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ content: editingContent }),
      });
      const j = await res.json();
      if (j.ok) {
        setEditingId(null);
        setMessage("댓글이 수정되었습니다.");
        logger.info("Comments", `수정 완료 (${id})`);
        load();
      } else {
        setMessage(j.error?.message ?? "수정에 실패했습니다.");
      }
    } catch {
      setMessage("네트워크 오류가 발생했습니다.");
    } finally {
      setSubmitting(false);
    }
  };

  // 댓글 삭제 (본인 + PENDING, 대댓글 포함)
  const removeComment = async (id: string) => {
    if (!confirm("댓글을 삭제하시겠습니까? (대댓글 포함 삭제됩니다)")) return;
    try {
      const res = await fetch(`/api/posts/${slug}/comments/${id}`, { method: "DELETE" });
      const j = await res.json();
      if (j.ok) {
        setMessage("댓글이 삭제되었습니다.");
        logger.info("Comments", `삭제 완료 (${id})`);
        load();
      } else {
        setMessage(j.error?.message ?? "삭제에 실패했습니다.");
      }
    } catch {
      setMessage("네트워크 오류가 발생했습니다.");
    }
  };

  const statusBadge = (s: string) =>
    s === "PENDING" ? (
      <span className="px-1.5 py-0.5 rounded bg-warning-soft text-warning text-[10px]">승인 대기 중</span>
    ) : null;

  const canManage = (c: { status: string; userId: string | null }) =>
    c.status === "PENDING" && !!session?.user && session.user.id === c.userId;

  return (
    <section className="mt-12 border-t border-border pt-8" id="comments">
      <h2 className="text-xl font-bold mb-6">댓글 {comments.length}</h2>

      {/* 작성 폼 */}
      {status === "loading" ? null : session?.user ? (
        <form onSubmit={submit} className="mb-8">
          <div className="flex items-center gap-2 mb-2">
            {session.user.image && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={session.user.image} alt="" className="w-8 h-8 rounded-full" />
            )}
            <span className="text-sm font-medium">{session.user.name}</span>
          </div>
          <textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            rows={3}
            maxLength={1000}
            placeholder="댓글을 남겨주세요. 첫 댓글 작성 시 다운로드 링크가 공개됩니다."
            className="w-full border border-input-border rounded-lg p-3 text-sm"
            aria-label="댓글 내용"
          />
          {/* honeypot — 숨겨진 스팸 함정 */}
          <input
            type="text"
            value={website}
            onChange={(e) => setWebsite(e.target.value)}
            className="hidden"
            tabIndex={-1}
            autoComplete="off"
            aria-hidden="true"
          />
          {replyTo && (
            <div className="text-xs text-text-muted mt-1">
              대댓글 작성 중{" "}
              <button type="button" className="text-primary" onClick={() => setReplyTo(null)}>
                취소
              </button>
            </div>
          )}
          <div className="mt-2">
            <button
              type="submit"
              disabled={submitting || !content.trim()}
              className="px-4 py-2 rounded-lg bg-primary text-white text-sm disabled:opacity-50"
            >
              {submitting ? "등록 중..." : "댓글 등록"}
            </button>
          </div>
          {message && <p className="text-sm text-success mt-2">{message}</p>}
        </form>
      ) : (
        <div className="mb-8 p-4 border border-border rounded-lg text-center text-sm text-text-secondary">
          댓글을 남기려면{" "}
          <button onClick={() => signIn("google")} className="text-primary font-medium">
            Google 로그인
          </button>
          이 필요합니다.
        </div>
      )}

      {/* 댓글 목록 */}
      {comments.length === 0 ? (
        <p className="text-text-muted text-sm text-center py-6">아직 댓글이 없습니다. 첫 댓글을 남겨보세요!</p>
      ) : (
        <ul className="space-y-4">
          {comments.map((c) => (
            <li key={c.id} className="border border-border rounded-lg p-4">
              <div className="flex items-center gap-2 mb-1">
                {c.user.image && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={c.user.image} alt="" className="w-6 h-6 rounded-full" />
                )}
                <span className="text-sm font-medium">{c.user.name ?? "익명"}</span>
                <span className="text-xs text-text-muted">{fmt(c.createdAt)}</span>
                {statusBadge(c.status)}
              </div>
              {editingId === c.id ? (
                <div>
                  <textarea
                    value={editingContent}
                    onChange={(e) => setEditingContent(e.target.value)}
                    rows={3}
                    maxLength={1000}
                    className="w-full border border-input-border rounded-lg p-3 text-sm"
                    aria-label="댓글 수정 내용"
                  />
                  <div className="mt-2 flex gap-2">
                    <button
                      onClick={() => saveEdit(c.id)}
                      disabled={submitting}
                      className="px-3 py-1 rounded-lg bg-primary text-white text-xs"
                    >
                      저장
                    </button>
                    <button
                      onClick={() => setEditingId(null)}
                      className="px-3 py-1 rounded-lg border border-input-border text-xs"
                    >
                      취소
                    </button>
                  </div>
                </div>
              ) : (
                <p className="text-sm whitespace-pre-wrap">{c.content}</p>
              )}
              <div className="mt-2 flex gap-3">
                {session?.user && (
                  <button onClick={() => setReplyTo(c.id)} className="text-xs text-primary">
                    답글
                  </button>
                )}
                {canManage(c) && (
                  <>
                    <button
                      onClick={() => {
                        setEditingId(c.id);
                        setEditingContent(c.content);
                      }}
                      className="text-xs text-text-muted"
                    >
                      수정
                    </button>
                    <button onClick={() => removeComment(c.id)} className="text-xs text-danger">
                      삭제
                    </button>
                  </>
                )}
              </div>
              {c.replies.length > 0 && (
                    <ul className="mt-3 space-y-2 pl-4 border-l-2 border-border">
                      {c.replies.map((r) => (
                        <li key={r.id}>
                          <div className="flex items-center gap-2">
                            {r.user.image && (
                              // eslint-disable-next-line @next/next/no-img-element
                              <img src={r.user.image} alt="" className="w-5 h-5 rounded-full" />
                            )}
                            <span className="text-sm font-medium">{r.user.name ?? "익명"}</span>
                            <span className="text-xs text-text-muted">{fmt(r.createdAt)}</span>
                            {statusBadge(r.status)}
                          </div>
                          {editingId === r.id ? (
                            <div>
                              <textarea
                                value={editingContent}
                                onChange={(e) => setEditingContent(e.target.value)}
                                rows={2}
                                maxLength={1000}
                                className="w-full border border-input-border rounded-lg p-2 text-sm"
                                aria-label="대댓글 수정 내용"
                              />
                              <div className="mt-1 flex gap-2">
                                <button
                                  onClick={() => saveEdit(r.id)}
                                  disabled={submitting}
                                  className="px-3 py-1 rounded-lg bg-primary text-white text-xs"
                                >
                                  저장
                                </button>
                                <button
                                  onClick={() => setEditingId(null)}
                                  className="px-3 py-1 rounded-lg border border-input-border text-xs"
                                >
                                  취소
                                </button>
                              </div>
                            </div>
                          ) : (
                            <p className="text-sm whitespace-pre-wrap">{r.content}</p>
                          )}
                          {canManage(r) && (
                            <div className="mt-1 flex gap-3">
                              <button
                                onClick={() => {
                                  setEditingId(r.id);
                                  setEditingContent(r.content);
                                }}
                                className="text-xs text-text-muted"
                              >
                                수정
                              </button>
                              <button onClick={() => removeComment(r.id)} className="text-xs text-danger">
                                삭제
                              </button>
                            </div>
                          )}
                        </li>
                      ))}
                    </ul>
                  )}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}