// [FEATURE] 비로그인 환영 배너 — T-18 (iosgods "Hello there! 👋" 패턴)
// 로그인하지 않은 방문자에게 댓글 게이트 참여 유도 (글 상세 상단)
"use client";

import { useSession, signIn } from "next-auth/react";
import { useEffect, useState } from "react";
import { logger } from "@/lib/logger";

export default function WelcomeBanner() {
  const { data: session, status } = useSession();
  const [shown, setShown] = useState(false);

  useEffect(() => {
    if (status === "unauthenticated") {
      setShown(true);
      logger.info("WelcomeBanner", "비로그인 방문자 배너 표시");
    }
  }, [status]);

  if (!shown) return null;

  return (
    <div className="card mb-6 p-5 bg-gradient-to-r from-primary-soft/70 to-accent-soft/40 border-primary/20" role="note">
      <div className="flex flex-col sm:flex-row sm:items-center gap-3">
        <div className="flex-1">
          <div className="font-bold mb-1">안녕하세요! 👋</div>
          <p className="text-sm text-text-secondary">
            댓글을 1개 이상 남기면 일부 글의 <strong>다운로드 링크가 공개</strong>됩니다.
            Google 로그인만 하면 바로 참여할 수 있어요.
          </p>
        </div>
        <button
          onClick={() => {
            logger.info("WelcomeBanner", "로그인 유도 클릭");
            signIn("google");
          }}
          className="btn-primary shrink-0"
        >
          로그인하고 시작하기
        </button>
      </div>
    </div>
  );
}