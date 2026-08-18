// [FEATURE] 댓글 로직 — T-04
// 스팸 방지: honeypot + rate limit(IP 10분 5개) + 관리자 승인(PENDING)
// 승인 모드: 첫 댓글은 PENDING — 관리자(macOS 앱) 승인 후 공개
import { db } from "./db";
import { logger } from "./logger";
import { bumpDailyStat } from "./stats"; // T-59: 일별 통계

export const COMMENT_RATE_LIMIT = 5; // 10분 내 5개
export const COMMENT_RATE_WINDOW_MS = 10 * 60 * 1000;

export interface CreateCommentInput {
  postId: string;
  userId: string;
  content: string;
  parentId?: string;
  ipAddress?: string;
}

// 댓글 생성 (스팸 검사 포함)
export async function createComment(input: CreateCommentInput) {
  const { postId, userId, content, parentId, ipAddress } = input;

  if (content.trim().length < 2) {
    return { error: "E-WEB-VALID-1001" as const };
  }
  if (content.length > 1000) {
    return { error: "E-WEB-VALID-1001" as const };
  }

  // rate limit: IP 기준 10분 내 5개 초과 시 거부
  if (ipAddress) {
    const recent = await db.comment.count({
      where: {
        ipAddress,
        createdAt: { gte: new Date(Date.now() - COMMENT_RATE_WINDOW_MS) },
      },
    });
    if (recent >= COMMENT_RATE_LIMIT) {
      logger.warn("Comment", `rate limit 초과 (ip=${ipAddress})`);
      return { error: "E-WEB-VALID-1001" as const };
    }
  }

  // 부모 댓글 검증
  if (parentId) {
    const parent = await db.comment.findUnique({ where: { id: parentId } });
    if (!parent || parent.postId !== postId) {
      return { error: "E-WEB-VALID-1001" as const };
    }
  }

  // 게시글 존재 검증
  const post = await db.post.findFirst({ where: { id: postId, status: "PUBLISHED" } });
  if (!post) return { error: "E-WEB-VALID-1001" as const };

  const comment = await db.comment.create({
    data: {
      postId,
      userId,
      parentId,
      content: content.trim(),
      status: "PENDING", // 관리자 승인 대기
      ipAddress,
    },
  });

  logger.info("Comment", `생성 (id=${comment.id}, post=${postId}, user=${userId})`);
  bumpDailyStat("comments"); // T-59: 일별 통계 (PENDING 포함 — 활동 추세)
  return { comment };
}

// 승인된 댓글 목록 (대댓글 트리 구조)
// 본인 PENDING 댓글은 승인 전에도 표시 (수정/삭제 가능)
export async function getComments(postId: string, viewerId?: string) {
  const comments = await db.comment.findMany({
    where: {
      postId,
      OR: [{ status: "APPROVED" }, viewerId ? { userId: viewerId, status: "PENDING" } : {}],
    },
    include: { user: { select: { id: true, name: true, image: true } } },
    orderBy: { createdAt: "asc" },
  });

  const roots = comments.filter((c) => !c.parentId);
  const replies = comments.filter((c) => c.parentId);

  const tree = roots.map((root) => ({
    ...root,
    replies: replies.filter((r) => r.parentId === root.id),
  }));

  logger.info("Comment", `목록 조회 (post=${postId}, total=${comments.length})`);
  return tree;
}

// 댓글 수정 (본인 + PENDING만)
export async function updateComment(input: {
  commentId: string;
  userId: string;
  content: string;
}) {
  const { commentId, userId, content } = input;
  const trimmed = content.trim();

  if (trimmed.length < 2 || trimmed.length > 1000) {
    return { error: "E-WEB-VALID-1001" as const };
  }

  const comment = await db.comment.findUnique({ where: { id: commentId } });
  if (!comment) return { error: "E-WEB-VALID-1001" as const };
  if (comment.userId !== userId) return { error: "E-WEB-AUTH-1001" as const };
  if (comment.status !== "PENDING") {
    return { error: "E-WEB-VALID-1001" as const }; // 승인된 댓글은 수정 불가
  }

  const updated = await db.comment.update({
    where: { id: commentId },
    data: { content: trimmed, status: "PENDING" },
  });
  logger.info("Comment", `수정 (id=${commentId}, user=${userId})`);
  return { comment: updated };
}

// 댓글 삭제 (본인 + PENDING만)
export async function deleteComment(input: { commentId: string; userId: string }) {
  const { commentId, userId } = input;

  const comment = await db.comment.findUnique({ where: { id: commentId } });
  if (!comment) return { error: "E-WEB-VALID-1001" as const };
  if (comment.userId !== userId) return { error: "E-WEB-AUTH-1001" as const };
  if (comment.status !== "PENDING") {
    return { error: "E-WEB-VALID-1001" as const }; // 승인된 댓글은 관리자만 삭제
  }

  // 대댓글도 함께 삭제
  await db.comment.deleteMany({ where: { OR: [{ id: commentId }, { parentId: commentId }] } });
  logger.info("Comment", `삭제 (id=${commentId}, user=${userId})`);
  return { ok: true };
}

// 사용자의 승인된 댓글 수 (다운로드 게이트 판정)
export async function getUserApprovedCommentCount(userId: string) {
  return db.comment.count({ where: { userId, status: "APPROVED" } });
}