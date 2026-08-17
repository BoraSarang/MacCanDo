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
    <select
      aria-label="정렬"
      value={value}
      onChange={(e) => {
        const url = new URL(basePath, window.location.origin);
        if (e.target.value === "views") url.searchParams.set("sort", "views");
        else url.searchParams.delete("sort");
        router.push(`${url.pathname}${url.search}`);
      }}
      className="px-3 py-1.5 rounded-lg bg-surface-hover text-sm text-text-secondary cursor-pointer"
    >
      <option value="latest">최신순</option>
      <option value="views">조회수순</option>
    </select>
  );
}