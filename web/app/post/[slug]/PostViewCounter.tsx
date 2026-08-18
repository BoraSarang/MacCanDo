// [FEATURE] 조회수 기록 — T-60
// SSG 페이지에서 마운트 시 1회 기록 (PAGE 제외). StrictMode 더블 인보크 대비 ref 가드.
"use client";

import { useEffect, useRef } from "react";

export default function PostViewCounter({ slug, isPage }: { slug: string; isPage: boolean }) {
  const sent = useRef(false);

  useEffect(() => {
    if (isPage || sent.current) return;
    sent.current = true;
    fetch(`/api/posts/${slug}/view`, { method: "POST" }).catch(() => {});
  }, [slug, isPage]);

  return null;
}