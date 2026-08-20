// [FEATURE] 카테고리 관리 API (개별) — v2.11 (T-64)
// PATCH  /api/admin/categories/[id]   — 수정 { name?, slug?, description?, icon?, sort? }
// DELETE /api/admin/categories/[id]   — 삭제 (연결된 PostCategory는 cascade)
import { withApi, apiOk, apiError } from "@/lib/api";
import { getAdminUser } from "@/lib/admin";
import { updateCategory, deleteCategory } from "@/lib/categories";

export const PATCH = withApi(async (req, { params }: { params: Promise<{ id: string }> }) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "PATCH", path: `/api/admin/categories/${(await params).id}` });
  }
  const id = (await params).id;
  const body = (await req.json()) as { name?: string; slug?: string; description?: string | null; icon?: string | null; sort?: number };
  if (body.slug !== undefined && !body.slug.trim()) {
    return apiError("E-WEB-VALID-1002", 400, { method: "PATCH", path: `/api/admin/categories/${id}` });
  }
  try {
    const patch: typeof body & { slug?: string } = { ...body };
    if (patch.slug) patch.slug = patch.slug.toLowerCase();
    const cat = await updateCategory(id, patch);
    return apiOk(cat, { method: "PATCH", path: `/api/admin/categories/${id}` });
  } catch {
    return apiError("E-WEB-CAT-1001", 409, { method: "PATCH", path: `/api/admin/categories/${id}` });
  }
}, "AdminCategoriesUpdate");

export const DELETE = withApi(async (req, { params }: { params: Promise<{ id: string }> }) => {
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "DELETE", path: `/api/admin/categories/${(await params).id}` });
  }
  const id = (await params).id;
  try {
    const cat = await deleteCategory(id);
    return apiOk({ id: cat.id }, { method: "DELETE", path: `/api/admin/categories/${id}` });
  } catch {
    return apiError("E-WEB-CAT-1001", 409, { method: "DELETE", path: `/api/admin/categories/${id}` });
  }
}, "AdminCategoriesDelete");