// [FEATURE] 게시글 상세 API — T-03
// GET /api/posts/[slug]
import { withApi, apiOk, apiError } from "@/lib/api";
import { getPostBySlug } from "@/lib/posts";

export const GET = withApi(async (_req, ctx: { params: Promise<{ slug: string }> }) => {
  const { slug } = await ctx.params;
  const post = await getPostBySlug(slug);
  if (!post) {
    return apiError("E-WEB-DB-1001", 404, { method: "GET", path: `/api/posts/${slug}` });
  }
  return apiOk(post);
}, "PostDetail");