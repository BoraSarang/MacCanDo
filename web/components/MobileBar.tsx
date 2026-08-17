// [FEATURE] 모바일 하단 고정 바 — 검색/네비/"..." 더보기 (T-17, appstorrent 패턴)
// md 미만에서만 표시. "..." 드롭업: About/Privacy/Disclaimer/Terms/FAQ/Contact + 닫기
"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { logger } from "@/lib/logger";

const MENU = [
  { href: "/apps", label: "맥 앱" },
  { href: "/category/os", label: "OS" },
  { href: "/category/games", label: "게임" },
  { href: "/tips", label: "맥 팁" },
  { href: "/news", label: "맥 소식" },
  { href: "/series", label: "시리즈" },
];

const PAGE_LINKS = [
  { href: "/post/about", label: "About" },
  { href: "/post/privacy-policy", label: "Privacy Policy" },
  { href: "/post/disclaimer", label: "Disclaimer" },
  { href: "/post/terms", label: "Terms of Service" },
  { href: "/post/faq", label: "FAQ" },
  { href: "/post/contact", label: "Contact Us" },
];

type Panel = "search" | "nav" | "more" | null;

export default function MobileBar() {
  const router = useRouter();
  const [panel, setPanel] = useState<Panel>(null);
  const [query, setQuery] = useState("");

  const toggle = (p: Exclude<Panel, null>) => {
    const next = panel === p ? null : p;
    setPanel(next);
    logger.info("MobileBar", `${p} 패널 ${next ? "열림" : "닫힘"}`);
  };

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!query.trim()) return;
    logger.info("MobileBar", `검색 실행: ${query}`);
    setPanel(null);
    router.push(`/search?q=${encodeURIComponent(query.trim())}`);
  };

  const go = (label: string) => {
    logger.info("MobileBar", `${label} 이동`);
    setPanel(null);
  };

  return (
    <>
      {/* 콘텐츠 하단 여백 (바 높이만큼) */}
      <div className="h-16 md:hidden" aria-hidden />

      <div
        id="mobile-bar"
        className="md:hidden fixed bottom-0 inset-x-0 z-20 bg-header-bg backdrop-blur border-t border-border"
        aria-label="모바일 하단 메뉴"
      >
        <div className="grid grid-cols-3">
          <button
            type="button"
            onClick={() => toggle("search")}
            className={`py-3 text-sm font-medium transition-colors ${panel === "search" ? "text-primary" : "text-text-secondary"}`}
          >
            🔍 검색
          </button>
          <button
            type="button"
            onClick={() => toggle("nav")}
            className={`py-3 text-sm font-medium transition-colors ${panel === "nav" ? "text-primary" : "text-text-secondary"}`}
          >
            ☰ 메뉴
          </button>
          <button
            type="button"
            onClick={() => toggle("more")}
            className={`py-3 text-sm font-medium transition-colors ${panel === "more" ? "text-primary" : "text-text-secondary"}`}
            aria-label="더보기"
          >
            ⋯
          </button>
        </div>

        {panel && (
          <div className="absolute bottom-full inset-x-0 max-h-[60vh] overflow-y-auto border-t border-border bg-bg shadow-lg">
            {panel === "search" && (
              <form onSubmit={submit} className="p-4 flex gap-2">
                <input
                  type="search"
                  value={query}
                  onChange={(e) => setQuery(e.target.value)}
                  placeholder="게시글 검색"
                  className="input flex-1"
                  autoFocus
                  aria-label="검색어 입력"
                />
                <button type="submit" className="btn-primary shrink-0">
                  검색
                </button>
              </form>
            )}
            {panel === "nav" && (
              <nav className="grid grid-cols-2 gap-1 p-3" aria-label="모바일 네비">
                {MENU.map((m) => (
                  <Link
                    key={m.href}
                    href={m.href}
                    onClick={() => go(m.label)}
                    className="px-3 py-2.5 rounded-lg text-sm text-text-secondary hover:bg-surface-hover hover:text-primary"
                  >
                    {m.label}
                  </Link>
                ))}
              </nav>
            )}
            {panel === "more" && (
              <div className="p-3">
                <div className="px-3 py-1.5 text-xs text-text-muted">사이트 정보</div>
                <div className="grid grid-cols-2 gap-1">
                  {PAGE_LINKS.map((l) => (
                    <Link
                      key={l.href}
                      href={l.href}
                      onClick={() => go(l.label)}
                      className="px-3 py-2.5 rounded-lg text-sm text-text-secondary hover:bg-surface-hover hover:text-primary"
                    >
                      {l.label}
                    </Link>
                  ))}
                </div>
                <button
                  type="button"
                  onClick={() => toggle("more")}
                  className="w-full mt-2 px-3 py-2.5 rounded-lg text-sm text-text-muted border border-border hover:bg-surface-hover"
                >
                  닫기
                </button>
              </div>
            )}
          </div>
        )}
      </div>
    </>
  );
}
