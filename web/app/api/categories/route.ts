// [FEATURE] 카테고리 API — T-03
// GET /api/categories
import { withApi, apiOk } from "@/lib/api";
import { getCategories } from "@/lib/posts";

export const GET = withApi(async () => {
  return apiOk(await getCategories());
}, "Categories");