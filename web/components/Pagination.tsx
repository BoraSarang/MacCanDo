// [FEATURE] 페이지네이션
import Link from "next/link";

export default function Pagination({
  page,
  totalPages,
  basePath,
}: {
  page: number;
  totalPages: number;
  basePath: string;
}) {
  if (totalPages <= 1) return null;

  const pages = Array.from({ length: totalPages }, (_, i) => i + 1);

  return (
    <nav className="flex justify-center gap-2 mt-8" aria-label="페이지네이션">
      {page > 1 && (
        <Link href={`${basePath}?page=${page - 1}`} className="btn-outline">
          이전
        </Link>
      )}
      {pages.map((p) => (
        <Link
          key={p}
          href={`${basePath}?page=${p}`}
          className={`btn ${p === page ? "bg-primary text-white" : "border border-border text-text-secondary"}`}
        >
          {p}
        </Link>
      ))}
      {page < totalPages && (
        <Link href={`${basePath}?page=${page + 1}`} className="btn-outline">
          다음
        </Link>
      )}
    </nav>
  );
}