// [FEATURE] 헤더 — 로고/카테고리 네비/검색 폼
"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState, useEffect } from "react";
import { logger } from "@/lib/logger";
import { useTheme } from "@/components/ThemeProvider";

interface Category {
  slug: string;
  name: string;
  postCount: number;
}

export default function Header() {
  const router = useRouter();
  const [categories, setCategories] = useState<Category[]>([]);
  const [query, setQuery] = useState("");
  const [isAdmin, setIsAdmin] = useState(false);
  const { dark, toggle } = useTheme();

  useEffect(() => {
    logger.info("Header", "카테고리 로드 시작");
    fetch("/api/categories")
      .then((r) => r.json())
      .then((j) => {
        if (j.ok) {
          setCategories(j.data);
          logger.info("Header", `카테고리 로드 완료 (${j.data.length}개)`);
        }
      })
      .catch((e) => logger.error("Header", `E-WEB-NET-1001 ${e.message}`));

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
        <Link href="/" className="font-bold text-lg shrink-0" onClick={() => logger.info("Header", "홈 이동")}>
          ⌘ MacCanDo
        </Link>

        <nav className="hidden md:flex gap-4 text-sm">
          {categories.map((c) => (
            <Link
              key={c.slug}
              href={`/category/${c.slug}`}
              className="text-text-secondary hover:text-primary"
            >
              {c.name}
            </Link>
          ))}
        </nav>

        <form onSubmit={submit} className="ml-auto flex items-center gap-2">
          <input
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="게시글 검색"
            className="input w-40 md:w-56"
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
          <Link
            href="/series"
            className="px-3 py-1.5 rounded-lg border border-border text-text-secondary text-sm hover:bg-surface-hover"
            onClick={() => logger.info("Header", "시리즈 이동")}
          >
            시리즈
          </Link>
          <button
            onClick={() => {
              toggle();
              logger.info("Header", `테마 전환 → ${dark ? "라이트" : "다크"}`);
            }}
            className="px-2.5 py-1.5 rounded-lg border border-border text-text-secondary text-sm hover:bg-surface-hover"
            aria-label="다크모드 전환"
            title="다크모드 전환"
          >
            {dark ? "☀️" : "🌙"}
          </button>
        </form>
      </div>

      {/* 모바일 카테고리 */}
      <nav className="md:hidden flex gap-3 px-4 pb-2 overflow-x-auto text-sm">
        {categories.map((c) => (
          <Link key={c.slug} href={`/category/${c.slug}`} className="text-text-secondary shrink-0">
            {c.name}
          </Link>
        ))}
      </nav>
    </header>
  );
}