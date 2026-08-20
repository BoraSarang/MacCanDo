// [FEATURE] 카테고리 관리 로직 — v2.11 (T-64)
// 관리: createCategory / updateCategory / deleteCategory / getAdminCategories (macOS 설정 → /api/admin/categories)
import { db } from "./db";
import { logger } from "./logger";

export interface CategoryInput {
  name: string;
  slug: string;
  description?: string | null;
  icon?: string | null;
  sort?: number;
  parentId?: string | null;
}

export async function getAdminCategories() {
  const cats = await db.category.findMany({
    orderBy: { sort: "asc" },
    include: { _count: { select: { posts: true } } },
  });
  return cats.map((c) => ({
    id: c.id,
    slug: c.slug,
    name: c.name,
    description: c.description,
    icon: c.icon,
    sort: c.sort,
    parentId: c.parentId,
    postCount: c._count.posts,
  }));
}

export async function createCategory(data: CategoryInput) {
  const cat = await db.category.create({
    data: {
      name: data.name,
      slug: data.slug,
      description: data.description ?? null,
      icon: data.icon ?? null,
      sort: data.sort ?? 0,
      parentId: data.parentId ?? null,
    },
  });
  logger.info("Category", `카테고리 생성: ${cat.name} (${cat.slug})`);
  return cat;
}

export async function updateCategory(id: string, data: Partial<CategoryInput>) {
  const patch: {
    name?: string;
    slug?: string;
    description?: string | null;
    icon?: string | null;
    sort?: number;
    parentId?: string | null;
  } = {};
  if (data.name !== undefined) patch.name = data.name;
  if (data.slug !== undefined) patch.slug = data.slug;
  if (data.description !== undefined) patch.description = data.description;
  if (data.icon !== undefined) patch.icon = data.icon;
  if (data.sort !== undefined) patch.sort = data.sort;
  if (data.parentId !== undefined) patch.parentId = data.parentId;
  const cat = await db.category.update({ where: { id }, data: patch });
  logger.info("Category", `카테고리 수정: ${cat.name} (${cat.slug})`);
  return cat;
}

export async function deleteCategory(id: string) {
  const cat = await db.category.delete({ where: { id } });
  logger.info("Category", `카테고리 삭제: ${cat.name} (${cat.slug})`);
  return cat;
}