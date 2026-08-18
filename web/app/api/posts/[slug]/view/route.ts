// [FEATURE] 조회수 기록 API — T-60
// POST /api/posts/[slug]/view — SSG 페이지에서 클라이언트가 1회 호출 (조회수 + 일별 통계)
import { withApi, apiOk } from "@/lib/api";
import { incrementPostView } from "@/lib/posts";

export const POST = withApi(async (_req, ctx: { params: Promise<{ slug: string }> }) => {
  const { slug } = await ctx.params;
  await incrementPostView(slug);
  return apiOk({ recorded: true });
}, "PostView");
