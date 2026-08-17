// [FEATURE] 글 본문 렌더 + 갤러리 라이트박스 (T-13) + 코드 블록 복사 (T-14 후속)
"use client";

import { useCallback, useEffect, useRef, useState } from "react";

export default function PostBody({ html }: { html: string }) {
  const [lightbox, setLightbox] = useState<string | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  const close = useCallback(() => setLightbox(null), []);

  useEffect(() => {
    if (!lightbox) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") close();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [lightbox, close]);

  // 코드 블록 복사 버튼 (모바일/데스크톱 공용, 실패 시 execCommand 폴백)
  useEffect(() => {
    const root = containerRef.current;
    if (!root) return;
    const pres = root.querySelectorAll("pre");
    pres.forEach((pre) => {
      if (pre.querySelector("[data-copy-btn]")) return;
      pre.style.position = "relative";
      const btn = document.createElement("button");
      btn.type = "button";
      btn.dataset.copyBtn = "true";
      btn.setAttribute("aria-label", "코드 복사");
      btn.title = "코드 복사";
      btn.textContent = "📋";
      Object.assign(btn.style, {
        position: "absolute",
        top: "8px",
        right: "8px",
        padding: "3px 8px",
        borderRadius: "6px",
        border: "none",
        background: "rgba(255,255,255,0.12)",
        color: "#fff",
        fontSize: "13px",
        cursor: "pointer",
        opacity: "0.7",
        transition: "opacity 150ms",
      } as CSSStyleDeclaration);
      btn.addEventListener("mouseenter", () => (btn.style.opacity = "1"));
      btn.addEventListener("mouseleave", () => (btn.style.opacity = "0.7"));
      btn.addEventListener("click", async () => {
        const code = pre.querySelector("code");
        const text = code ? (code as HTMLElement).innerText : pre.innerText;
        let ok = false;
        try {
          if (navigator.clipboard && window.isSecureContext) {
            await navigator.clipboard.writeText(text);
            ok = true;
          }
        } catch {
          ok = false;
        }
        if (!ok) {
          const ta = document.createElement("textarea");
          ta.value = text;
          ta.style.position = "fixed";
          ta.style.opacity = "0";
          document.body.appendChild(ta);
          ta.select();
          try {
            ok = document.execCommand("copy");
          } finally {
            document.body.removeChild(ta);
          }
        }
        btn.textContent = ok ? "✓" : "✗";
        setTimeout(() => (btn.textContent = "📋"), 1600);
      });
      pre.appendChild(btn);
    });
  }, [html]);

  return (
    <>
      <div
        ref={containerRef}
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