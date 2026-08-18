// [FEATURE] 본인 승인 댓글 수 API — T-60 (게이트 판정용)
// GET /api/posts/[slug]/mine — 로그인 사용자의 승인된 댓글 수 (다운로드 게이트: 1개 이상이면 공개)
import { withApi, apiOk, apiError } from "@/lib/api";
import { auth } from "@/auth";
import { getUserApprovedCommentCount } from "@/lib/comments";

export const GET = withApi(async (_req, ctx: { params: Promise<{ slug: string }> }) => {
  const { slug } = await ctx.params;
  const session = await auth();
  if (!session?.user?.id) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "GET", path: `/api/posts/${slug}/mine` });
  }
  const count = await getUserApprovedCommentCount(session.user.id);
  return apiOk({ approvedCount: count });
}, "MyComments");