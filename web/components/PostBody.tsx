// [FEATURE] 글 본문 렌더 + 갤러리 라이트박스 (T-13)
"use client";

import { useCallback, useEffect, useState } from "react";

export default function PostBody({ html }: { html: string }) {
  const [lightbox, setLightbox] = useState<string | null>(null);

  const close = useCallback(() => setLightbox(null), []);

  useEffect(() => {
    if (!lightbox) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") close();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [lightbox, close]);

  return (
    <>
      <div
        className="prose-content"
        dangerouslySetInnerHTML={{ __html: html }}
        onClick={(e) => {
          const img = (e.target as HTMLElement).closest("img");
          if (img && img.closest(".gallery-grid")) setLightbox(img.src);
        }}
      />
      {lightbox && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label="스크린샷 확대"
          className="fixed inset-0 z-50 bg-black/85 flex items-center justify-center p-6 cursor-zoom-out"
          onClick={close}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={lightbox}
            alt="스크린샷 확대"
            className="max-h-full max-w-full rounded-lg shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          />
          <button
            type="button"
            onClick={close}
            aria-label="닫기"
            className="absolute top-4 right-4 w-10 h-10 rounded-full bg-white/15 text-white text-xl hover:bg-white/30 transition-colors"
          >
            ✕
          </button>
        </div>
      )}
    </>
  );
}