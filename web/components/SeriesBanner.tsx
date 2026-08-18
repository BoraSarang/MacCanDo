// [FEATURE] 홈 시리즈 배너 — 광고 슬롯 (T-11)
// 관리자 지정 시리즈(featuredOrder) 우선 + 전체 시리즈로 자동 채움
// 나중에 광고 삽입 시 이 컴포넌트 내부를 광고 코드로 교체 (슬롯 구조 유지)
// framer-motion spring (apple-design)
"use client";

import Link from "next/link";
import { motion, useReducedMotion } from "framer-motion";
import type { SeriesOverview } from "@/lib/series";

const MotionLink = motion(Link);

export default function SeriesBanner({ series }: { series: SeriesOverview[] }) {
  const reduced = useReducedMotion();
  if (series.length === 0) return null;
  const hover = reduced ? undefined : { y: -3 };
  const tap = reduced ? undefined : { scale: 0.985 };
  const spring = { type: "spring", bounce: 0, duration: 0.3 } as const;
  return (
    <section className="mb-10">
      <div className="flex items-end justify-between mb-4">
        <h2 className="text-xl font-bold">시리즈</h2>
        <Link href="/series" className="text-sm text-primary hover:underline">
          전체 보기 →
        </Link>
      </div>
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {series.map((s) => (
          <MotionLink
            key={s.id}
            href={`/series/${s.id}`}
            className="group card overflow-hidden hover:border-primary/50 hover:shadow-md transition-all"
            whileHover={hover}
            whileTap={tap}
            transition={spring}
          >
            <div className="relative aspect-[16/9] bg-surface-hover">
              {s.imageUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={s.imageUrl}
                  alt={s.title}
                  className="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                />
              ) : (
                <div className="absolute inset-0 flex items-center justify-center text-3xl font-bold text-primary/20">
                  {s.title.slice(0, 1)}
                </div>
              )}
              <span className="absolute top-2 right-2 bg-black/60 text-white text-[11px] px-2 py-0.5 rounded-full">
                {s.posts.length}개의 글
              </span>
            </div>
            <div className="p-3">
              <div className="font-semibold line-clamp-2 group-hover:text-primary transition-colors">{s.title}</div>
              {s.description && <div className="text-xs text-text-muted mt-1 line-clamp-1">{s.description}</div>}
            </div>
          </MotionLink>
        ))}
      </div>
    </section>
  );
}