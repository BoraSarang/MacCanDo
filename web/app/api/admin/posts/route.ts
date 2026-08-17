// [FEATURE] 관리자 게시글 API — T-05/T-07
// GET /api/admin/posts — 게시글별 조회수/다운로드/댓글 (통계)
// GET /api/admin/posts?all=1 — 관리자용 전체 목록 (DRAFT 포함)
// POST /api/admin/posts — 새 게시글 (macOS 에디터)
import { withApi, apiOk, apiError } from "@/lib/api";
import { getAdminUser } from "@/lib/admin";
import { getAdminPostStats } from "@/lib/downloads";
import { createPost, type PostInput } from "@/lib/posts";
import { db } from "@/lib/db";

export const GET = withApi(async (req) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "GET", path: "/api/admin/posts" });
  }
  const url = new URL(req.url);
  if (url.searchParams.get("all") === "1") {
    const posts = await db.post.findMany({
      orderBy: { updatedAt: "desc" },
      include: {
        categories: { include: { category: { select: { name: true, slug: true } } } },
        tags: { include: { tag: { select: { name: true, slug: true } } } },
      },
    });
    return apiOk(posts);
  }
  return apiOk(await getAdminPostStats());
}, "AdminPostStats");

export const POST = withApi(async (req) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "POST", path: "/api/admin/posts" });
  }
  const input = (await req.json()) as PostInput;
  const result = await createPost(input);
  if (!result.ok) {
    return apiError(result.error, result.error === "E-WEB-VALID-1001" ? 400 : 500, {
      method: "POST",
      path: "/api/admin/posts",
    });
  }
  return apiOk(result.post, { method: "POST", path: "/api/admin/posts" });
}, "AdminPostCreate");