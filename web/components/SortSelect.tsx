// [FEATURE] 목록 정렬 드롭다운 — 최신순/조회수순 (T-11)
"use client";
import { useRouter } from "next/navigation";

interface Props {
  value: "latest" | "views";
  basePath: string; // 쿼리 유지용 (예: /apps?category=develop)
}

export default function SortSelect({ value, basePath }: Props) {
  const router = useRouter();
  return (
    <div className="relative inline-flex items-center">
      <select
        aria-label="정렬"
        value={value}
        onChange={(e) => {
          const url = new URL(basePath, window.location.origin);
          if (e.target.value === "views") url.searchParams.set("sort", "views");
          else url.searchParams.delete("sort");
          router.push(`${url.pathname}${url.search}`);
        }}
        className="appearance-none pr-8 pl-3 py-1.5 rounded-lg bg-surface-hover text-sm text-text-secondary cursor-pointer"
      >
        <option value="latest">최신순</option>
        <option value="views">조회수순</option>
      </select>
      <svg
        aria-hidden
        className="pointer-events-none absolute right-2.5 w-3.5 h-3.5 text-text-muted"
        viewBox="0 0 16 16"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="M4 6l4 4 4-4" />
      </svg>
    </div>
  );
}