// [FEATURE] 헤더 — 로고/메뉴(맥 앱·맥 팁·맥 소식·시리즈)/검색 폼
"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState, useEffect } from "react";
import { logger } from "@/lib/logger";
import { useTheme } from "@/components/ThemeProvider";
import { SunIcon, MoonIcon } from "@/components/Icons";

const MENU = [
  { href: "/apps", label: "맥 앱" },
  { href: "/category/os", label: "OS" },
  { href: "/category/games", label: "게임" },
  { href: "/tips", label: "맥 팁" },
  { href: "/news", label: "맥 소식" },
];

export default function Header() {
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [isAdmin, setIsAdmin] = useState(false);
  const { dark, toggle } = useTheme();

  useEffect(() => {
    // 관리자 판정 (표시용 — 실제 권한은 서버 검증)
    fetch("/api/auth/session")
      .then((r) => r.json())
      .then((j) => {
        const admin = j?.user?.role === "ADMIN";
        setIsAdmin(admin);
        if (admin) logger.info("Header", "관리자 링크 표시");
      })
      .catch(() => setIsAdmin(false));
  }, []);

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!query.trim()) return;
    logger.info("Header", `검색 실행: ${query}`);
    router.push(`/search?q=${encodeURIComponent(query.trim())}`);
  };

  return (
    <header className="sticky top-0 z-10 bg-header-bg backdrop-blur border-b border-border">
      <div className="max-w-5xl mx-auto px-4 py-3 flex items-center gap-6">
        <Link href="/" className="flex items-center gap-2 shrink-0" onClick={() => logger.info("Header", "홈 이동")}>
          <span className="keycap w-7 h-7 text-sm text-text" aria-hidden>
            ⌘
          </span>
          <span className="font-bold text-lg">MacCanDo</span>
        </Link>

        <nav className="hidden md:flex gap-4 text-sm">
          {MENU.map((m) => (
            <Link
              key={m.href}
              href={m.href}
              className="text-text-secondary hover:text-primary"
              onClick={() => logger.info("Header", `${m.label} 이동`)}
            >
              {m.label}
            </Link>
          ))}
          <Link
            href="/series"
            className="text-text-secondary hover:text-primary"
            onClick={() => logger.info("Header", "시리즈 이동")}
          >
            시리즈
          </Link>
        </nav>

        <form onSubmit={submit} className="ml-auto flex-1 min-w-0 flex items-center gap-2 md:flex-none">
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="게시글 검색…"
            className="input flex-1 min-w-0 md:flex-none md:w-56"
            aria-label="검색어 입력"
          />
          <button type="submit" className="btn-primary">
            검색
          </button>
          {isAdmin && (
            <Link
              href="/admin"
              className="px-3 py-1.5 rounded-lg border border-primary text-primary text-sm hover:bg-primary-soft"
              onClick={() => logger.info("Header", "관리자 이동")}
            >
              관리자
            </Link>
          )}
          <button
            onClick={() => {
              toggle();
              logger.info("Header", `테마 전환 → ${dark ? "라이트" : "다크"}`);
            }}
            className="p-2 rounded-lg border border-border text-text-secondary hover:bg-surface-hover transition-colors"
            aria-label={dark ? "라이트 모드로 전환" : "다크 모드로 전환"}
            title={dark ? "라이트 모드로 전환" : "다크 모드로 전환"}
          >
            {dark ? <SunIcon className="w-4 h-4" /> : <MoonIcon className="w-4 h-4" />}
          </button>
        </form>
      </div>

      {/* 모바일 메뉴 */}
      <nav className="md:hidden flex gap-3 px-4 pb-2 overflow-x-auto text-sm">
        {MENU.map((m) => (
          <Link key={m.href} href={m.href} className="text-text-secondary shrink-0">
            {m.label}
          </Link>
        ))}
        <Link href="/series" className="text-text-secondary shrink-0">
          시리즈
        </Link>
      </nav>
    </header>
  );
}