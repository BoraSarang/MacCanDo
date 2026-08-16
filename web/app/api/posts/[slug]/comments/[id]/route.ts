// [FEATURE] 댓글 수정/삭제 API — T-04
// PUT    /api/posts/[slug]/comments/[id] — 본인 + PENDING만 수정
// DELETE /api/posts/[slug]/comments/[id] — 본인 + PENDING만 삭제 (대댓글 포함)
import { withApi, apiOk, apiError } from "@/lib/api";
import { auth } from "@/auth";
import { updateComment, deleteComment } from "@/lib/comments";

export const PUT = withApi(
  async (req, ctx: { params: Promise<{ slug: string; id: string }> }) => {
    const { slug, id } = await ctx.params;
    const session = await auth();
    if (!session?.user?.id) {
      return apiError("E-WEB-AUTH-1001", 401, { method: "PUT", path: `/api/posts/${slug}/comments/${id}` });
    }

    const body = (await req.json().catch(() => null)) as { content?: string };
    const result = await updateComment({
      commentId: id,
      userId: session.user.id,
      content: body?.content ?? "",
    });

    if ("error" in result) {
      return apiError(result.error ?? "E-WEB-VALID-1001", 400, {
        method: "PUT",
        path: `/api/posts/${slug}/comments/${id}`,
      });
    }
    return apiOk({ comment: result.comment });
  },
  "CommentUpdate"
);

export const DELETE = withApi(async (_req, ctx: { params: Promise<{ slug: string; id: string }> }) => {
  const { slug, id } = await ctx.params;
  const session = await auth();
  if (!session?.user?.id) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "DELETE", path: `/api/posts/${slug}/comments/${id}` });
  }

  const result = await deleteComment({ commentId: id, userId: session.user.id });
  if ("error" in result) {
    return apiError(result.error ?? "E-WEB-VALID-1001", 400, {
      method: "DELETE",
      path: `/api/posts/${slug}/comments/${id}`,
    });
  }
  return apiOk({ ok: true });
}, "CommentDelete");