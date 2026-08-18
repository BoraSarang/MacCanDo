// [FEATURE] 히어로 — ⌘ 키캡 시그니처 + spring 스태거 진입 (apple-design)
"use client";

import { motion, useReducedMotion } from "framer-motion";
import type { ReactNode } from "react";

const SPRING = { type: "spring", bounce: 0, duration: 0.45 } as const;

export default function Hero() {
  const reduced = useReducedMotion();

  const blocks: ReactNode[] = [
    <span key="k" className="keycap w-14 h-14 md:w-16 md:h-16 text-2xl md:text-3xl text-text mb-4" aria-hidden>
      ⌘
    </span>,
    <h1 key="h" className="type-display mb-3">
      맥으로{" "}
      <span className="bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent">이것도 할 수 있다</span>
    </h1>,
    <p key="p" className="text-text-secondary max-w-2xl mx-auto">
      유용한 Mac 프로그램 소개, 꿀팁 가이드, 최신 소식까지 — MacCanDo에서 확인하세요.
    </p>,
  ];

  return (
    <section className="text-center py-12 mb-8">
      {blocks.map((el, i) => (
        <motion.div
          key={i}
          initial={{ opacity: 0, y: reduced ? 0 : 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ ...SPRING, delay: i * 0.08 }}
        >
          {el}
        </motion.div>
      ))}
    </section>
  );
}