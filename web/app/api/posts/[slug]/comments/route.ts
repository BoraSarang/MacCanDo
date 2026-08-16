// [FEATURE] 댓글 API — T-04
// GET  /api/posts/[slug]/comments — 승인 댓글 + 본인 PENDING (승인 전 본인 보기)
// POST /api/posts/[slug]/comments — 댓글 작성 (로그인 필수, honeypot + rate limit)
import { withApi, apiOk, apiError } from "@/lib/api";
import { auth } from "@/auth";
import { createComment, getComments } from "@/lib/comments";
import { db } from "@/lib/db";
import { logger } from "@/lib/logger";

export const GET = withApi(async (_req, ctx: { params: Promise<{ slug: string }> }) => {
  const { slug } = await ctx.params;
  const post = await db.post.findFirst({ where: { slug, status: "PUBLISHED" } });
  if (!post) return apiError("E-WEB-DB-1001", 404, { method: "GET", path: `/api/posts/${slug}/comments` });
  const session = await auth();
  return apiOk(await getComments(post.id, session?.user?.id ?? undefined));
}, "Comments");

export const POST = withApi(async (req, ctx: { params: Promise<{ slug: string }> }) => {
  const { slug } = await ctx.params;
  const session = await auth();
  if (!session?.user?.id) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "POST", path: `/api/posts/${slug}/comments` });
  }
  const userId = session.user.id;

  const body = (await req.json().catch(() => null)) as {
    content?: string;
    parentId?: string;
    // honeypot — 사람은 이 필드를 채우지 않음
    website?: string;
  };

  // honeypot: 숨겨진 필드에 값이 있으면 스팸으로 간주
  if (body.website) {
    logger.warn("Comment", `honeypot 감지 (user=${session.user.id})`);
    // 스패머에게 성공처럼 보이게 하기
    return apiOk({ ok: true });
  }

  const post = await db.post.findFirst({ where: { slug, status: "PUBLISHED" } });
  if (!post) return apiError("E-WEB-DB-1001", 404, { method: "POST", path: `/api/posts/${slug}/comments` });

  const ipAddress = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";

  const result = await createComment({
    postId: post.id,
    userId,
    content: body.content ?? "",
    parentId: body.parentId ?? undefined,
    ipAddress,
  });

  if ("error" in result) {
    return apiError(result.error ?? "E-WEB-VALID-1001", 400, {
      method: "POST",
      path: `/api/posts/${slug}/comments`,
    });
  }

  return apiOk({ comment: result.comment, status: "PENDING" });
}, "CommentCreate");