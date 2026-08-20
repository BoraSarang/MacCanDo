// [FEATURE] 카테고리 관리 API — v2.11 (T-64)
// GET  /api/admin/categories          — 관리자용 카테고리 목록 (+글 수, 전체)
// POST /api/admin/categories          — 카테고리 생성 { name, slug, description?, icon?, sort? }
import { withApi, apiOk, apiError } from "@/lib/api";
import { getAdminUser } from "@/lib/admin";
import { getAdminCategories, createCategory } from "@/lib/categories";

export const GET = withApi(async (req) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "GET", path: "/api/admin/categories" });
  }
  return apiOk(await getAdminCategories(), { method: "GET", path: "/api/admin/categories" });
}, "AdminCategoriesList");

export const POST = withApi(async (req) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "POST", path: "/api/admin/categories" });
  }
  const body = (await req.json()) as { name?: string; slug?: string; description?: string | null; icon?: string | null; sort?: number };
  if (!body.name?.trim() || !body.slug?.trim()) {
    return apiError("E-WEB-VALID-1002", 400, { method: "POST", path: "/api/admin/categories" });
  }
  try {
    const cat = await createCategory({
      name: body.name.trim(),
      slug: body.slug.trim().toLowerCase(),
      description: body.description ?? null,
      icon: body.icon ?? null,
      sort: body.sort ?? 0,
    });
    return apiOk(cat, { method: "POST", path: "/api/admin/categories" });
  } catch {
    return apiError("E-WEB-CAT-1001", 409, { method: "POST", path: "/api/admin/categories" });
  }
}, "AdminCategoriesCreate");