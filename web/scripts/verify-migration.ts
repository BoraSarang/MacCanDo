// 검증: PostCategory 이전 확인
import { db } from "@/lib/db";

async function main() {
  const pc = await db.postCategory.count();
  const posts = await db.post.findMany({ select: { id: true, title: true, contentType: true } });
  console.log("PostCategory 이전:", pc, "건 / 글", posts.length, "편 / contentType 기본값:", posts.filter(p => p.contentType === "ARTICLE").length, "편");
  await db.$disconnect();
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});