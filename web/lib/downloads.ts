// [FEATURE] 다운로드 게이트 + 통계 로직 — T-05
// 게이트 판정: 로그인 + 승인 댓글 1개 이상 → 다운로드 링크 공개/리다이렉트
// 클릭 시 DownloadEvent 기록 (IP는 sha256 해시 저장 — 개인정보 보호)
import { createHash } from "crypto";
import { db } from "./db";
import { logger } from "./logger";

// 다운로드 게이트 판정
export async function checkDownloadGate(linkId: string, userId?: string) {
  const link = await db.downloadLink.findUnique({
    where: { id: linkId },
    include: { post: { select: { id: true, slug: true, status: true } } },
  });
  if (!link) return { ok: false as const, error: "E-WEB-DB-1001" };
  if (link.post.status !== "PUBLISHED") return { ok: false as const, error: "E-WEB-DB-1001" };

  // T-15: 앱 카드 링크(postAppId)는 공개 — 게이트 없이 통과
  if (link.postAppId) return { ok: true as const, link };

  // 로그인 필수
  if (!userId) return { ok: false as const, error: "E-WEB-AUTH-1001" };

  // 승인 댓글 1개 이상 필수
  const commentCount = await db.comment.count({
    where: { postId: link.postId, userId, status: "APPROVED" },
  });
  if (commentCount < 1) {
    logger.info("Download", `게이트 차단 (link=${linkId}, user=${userId}, comments=${commentCount})`);
    return { ok: false as const, error: "E-WEB-VALID-1001" };
  }

  return { ok: true as const, link };
}

// 클릭 이벤트 기록
export async function recordDownloadEvent(input: {
  linkId: string;
  postId: string;
  userId?: string;
  ip?: string;
}) {
  const ipHash = input.ip ? createHash("sha256").update(input.ip).digest("hex").slice(0, 16) : null;

  const event = await db.downloadEvent.create({
    data: {
      linkId: input.linkId,
      postId: input.postId,
      userId: input.userId ?? null,
      ipHash,
    },
  });

  await db.downloadLink.update({
    where: { id: input.linkId },
    data: { clickCount: { increment: 1 } },
  });

  logger.info("Download", `클릭 기록 (link=${input.linkId}, post=${input.postId}, user=${input.userId ?? "-"})`);
  return event;
}

// ===== 관리자 통계 =====

// 사이트 전체 요약
export async function getAdminSummary() {
  const [postCount, commentCount, pendingCommentCount, clickCount, userCount, views] =
    await Promise.all([
      db.post.count(),
      db.comment.count(),
      db.comment.count({ where: { status: "PENDING" } }),
      db.downloadEvent.count(),
      db.user.count(),
      db.post.aggregate({ _sum: { viewCount: true } }),
    ]);

  // 일별 통계 (최근 14일, 게시글 전체 집계)
  const daily = await db.dailyStat.groupBy({
    by: ["date"],
    _sum: { views: true, clicks: true, comments: true, newUsers: true },
    orderBy: { date: "desc" },
    take: 14,
  });

  return {
    postCount,
    commentCount,
    pendingCommentCount,
    clickCount,
    userCount,
    totalViews: views._sum.viewCount ?? 0,
    daily: daily.map((d) => ({
      date: d.date,
      views: d._sum.views ?? 0,
      clicks: d._sum.clicks ?? 0,
      comments: d._sum.comments ?? 0,
      newUsers: d._sum.newUsers ?? 0,
    })),
  };
}

// 게시글별 통계 (조회수/다운로드/댓글)
export async function getAdminPostStats() {
  const posts = await db.post.findMany({
    select: {
      id: true,
      title: true,
      slug: true,
      viewCount: true,
      status: true,
      publishedAt: true,
      excerpt: true,
      seoMeta: true,
      _count: {
        select: {
          comments: true,
          downloadEvents: true,
        },
      },
    },
    orderBy: { viewCount: "desc" },
    take: 50,
  });
  return posts;
}

// 승인 대기 댓글 목록
export async function getAdminComments(status?: string) {
  const valid = ["PENDING", "APPROVED", "SPAM"];
  return db.comment.findMany({
    where: status && valid.includes(status) ? { status: status as "PENDING" } : {},
    include: {
      user: { select: { id: true, name: true, email: true, image: true } },
      post: { select: { id: true, slug: true, title: true } },
    },
    orderBy: { createdAt: "desc" },
    take: 200,
  });
}

// 승인 대기 댓글 (기본 뷰)
export async function getPendingComments() {
  return getAdminComments("PENDING");
}

// 댓글 상태 변경 (승인/스팸) — 관리자 전용
export async function setCommentStatus(input: { commentId: string; status: "APPROVED" | "SPAM" | "PENDING" }) {
  const updated = await db.comment.update({
    where: { id: input.commentId },
    data: { status: input.status },
  });
  logger.info("Admin", `댓글 상태 변경 (id=${input.commentId}, status=${input.status})`);
  return updated;
}