// [FEATURE] 공용 모션 컴포넌트 — framer-motion (apple-design: spring damping 1.0, reduced-motion 존중)
"use client";

import { motion, useReducedMotion } from "framer-motion";
import type { ReactNode } from "react";

const SPRING = { type: "spring", bounce: 0, duration: 0.4 } as const;

/** 스크롤 진입 페이드 (y 8px → 0, 1회) */
export function FadeIn({ children, delay = 0, className }: { children: ReactNode; delay?: number; className?: string }) {
  const reduced = useReducedMotion();
  return (
    <motion.div
      className={className}
      initial={{ opacity: 0, y: reduced ? 0 : 8 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "0px 0px -48px 0px" }}
      transition={{ ...SPRING, delay }}
    >
      {children}
    </motion.div>
  );
}

/** 등장 페이드 (컴포넌트 마운트 시) */
export function FadeInMount({ children, delay = 0, className }: { children: ReactNode; delay?: number; className?: string }) {
  const reduced = useReducedMotion();
  return (
    <motion.div
      className={className}
      initial={{ opacity: 0, y: reduced ? 0 : 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ ...SPRING, delay }}
    >
      {children}
    </motion.div>
  );
}

/** 카드 hover/tap 물리 (whileHover y-lift, whileTap scale) */
export function CardMotion({ children, className }: { children: ReactNode; className?: string }) {
  const reduced = useReducedMotion();
  if (reduced) return <div className={className}>{children}</div>;
  return (
    <motion.div
      className={className}
      whileHover={{ y: -3 }}
      whileTap={{ scale: 0.985 }}
      transition={{ type: "spring", bounce: 0, duration: 0.3 }}
    >
      {children}
    </motion.div>
  );
}