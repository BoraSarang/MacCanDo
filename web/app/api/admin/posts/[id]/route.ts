// [FEATURE] 관리자 게시글 단건 API — T-07
// GET /api/admin/posts/[id] — DRAFT 포함 단건 (에디터 로드)
// PUT /api/admin/posts/[id] — 수정 (발행/초안 전환 포함)
// DELETE /api/admin/posts/[id] — 삭제
import { withApi, apiOk, apiError } from "@/lib/api";
import { getAdminUser } from "@/lib/admin";
import { updatePost, deletePost, type PostInput } from "@/lib/posts";
import { db } from "@/lib/db";

export const GET = withApi(async (_req, ctx: { params: Promise<{ id: string }> }) => {
  if (!(await getAdminUser(_req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "GET", path: "/api/admin/posts/[id]" });
  }
  const { id } = await ctx.params;
  const post = await db.post.findUnique({
    where: { id },
    include: { category: { select: { name: true, slug: true } } },
  });
  if (!post) {
    return apiError("E-WEB-POST-1003", 404, { method: "GET", path: `/api/admin/posts/${id}` });
  }
  return apiOk(post);
}, "AdminPostGet");

export const PUT = withApi(async (req, ctx: { params: Promise<{ id: string }> }) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "PUT", path: "/api/admin/posts/[id]" });
  }
  const { id } = await ctx.params;
  const input = (await req.json()) as PostInput;
  const result = await updatePost(id, input);
  if (!result.ok) {
    const status = result.error === "E-WEB-VALID-1001" ? 400 : result.error === "E-WEB-POST-1003" ? 404 : 500;
    return apiError(result.error, status, { method: "PUT", path: `/api/admin/posts/${id}` });
  }
  return apiOk(result.post, { method: "PUT", path: `/api/admin/posts/${id}` });
}, "AdminPostUpdate");

export const DELETE = withApi(async (_req, ctx: { params: Promise<{ id: string }> }) => {
  if (!(await getAdminUser(_req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "DELETE", path: "/api/admin/posts/[id]" });
  }
  const { id } = await ctx.params;
  const result = await deletePost(id);
  if (!result.ok) {
    const status = result.error === "E-WEB-POST-1003" ? 404 : 500;
    return apiError(result.error, status, { method: "DELETE", path: `/api/admin/posts/${id}` });
  }
  return apiOk({ id }, { method: "DELETE", path: `/api/admin/posts/${id}` });
}, "AdminPostDelete");