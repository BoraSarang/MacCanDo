// [FEATURE] 다운로드 게이트 — T-60 (SSG 정적화)
// 서버 판정 → 클라이언트 판정 전환: session + 본인 승인 댓글 수로 잠금/공개 결정
// 최종 다운로드는 서버 라우트(/download/[dlId])가 재검증 — 보안 강도 동일
"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

export type GateLink = { id: string; label: string; type: string };

export default function GateCheck({
  slug,
  links,
}: {
  slug: string;
  links: GateLink[];
}) {
  const [state, setState] = useState<"loading" | "locked" | "unlocked">("loading");

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const sessionRes = await fetch("/api/auth/session");
        const session = await sessionRes.json();
        if (!session?.user?.id) {
          if (!cancelled) setState("locked");
          return;
        }
        const mineRes = await fetch(`/api/posts/${slug}/mine`);
        if (!mineRes.ok) {
          if (!cancelled) setState("locked");
          return;
        }
        const mine = await mineRes.json();
        if (!cancelled) setState(mine.data?.approvedCount >= 1 ? "unlocked" : "locked");
      } catch {
        if (!cancelled) setState("locked");
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [slug]);

  return (
    <section className="mt-10 card p-6 border-primary/30 bg-primary-soft/50">
      <h2 className="font-bold text-lg mb-1">다운로드</h2>
      {state === "unlocked" ? (
        <>
          <p className="text-sm text-text-secondary mb-4">댓글 작성 감사합니다! 다운로드 링크가 공개되었습니다.</p>
          {links.map((dl) => (
            <Link
              key={dl.id}
              href={`/post/${slug}/download/${dl.id}`}
              className="block border border-border-strong bg-bg rounded-lg px-4 py-3 mb-2 hover:border-primary/50 hover:shadow-sm transition-all"
            >
              <span className="font-semibold">{dl.label}</span>
              <span className="text-xs text-text-muted ml-2">
                ({dl.type === "OFFICIAL" ? "파일" : "웹 페이지"})
              </span>
            </Link>
          ))}
        </>
      ) : (
        <p className="text-sm text-text-secondary mb-4">
          {state === "loading"
            ? "다운로드 링크 확인 중…"
            : "다운로드 링크를 보려면 Google 로그인 후 댓글을 1개 이상 남겨주세요."}
        </p>
      )}
    </section>
  );
}