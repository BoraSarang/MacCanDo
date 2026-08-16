// [FEATURE] 이미지 목록 관리 — 파일 시스템 ↔ DB 동기화 (T-08)
// 원칙: 파일이 진실(서버 디스크), DB는 목록/캡션/사용처 메타데이터
// listImages()가 스캔 결과와 DB를 sync: 새 파일 → upsert, 없는 파일 → DB 정리
import { db } from "@/lib/db";
import { readdir, stat, unlink } from "fs/promises";
import path from "path";

export const UPLOAD_ROOT = path.join(process.cwd(), "public", "uploads");
const ALLOWED_EXT = new Set([".png", ".jpg", ".jpeg", ".gif", ".webp"]);

export type ImageItem = {
  url: string;
  name: string;
  size: number;
  date: string;
  caption: string | null;
  postTitle: string | null;
  postSlug: string | null;
};

// 파일 스캔 + DB upsert sync + 고아 정리 → DB 목록 반환 (최신순)
export async function listImages(): Promise<ImageItem[]> {
  const disk: Array<{ url: string; name: string; size: number; mtime: Date }> = [];
  const folders = await readdir(UPLOAD_ROOT).catch(() => []);
  for (const folder of folders) {
    const dir = path.join(UPLOAD_ROOT, folder);
    const info = await stat(dir).catch(() => null);
    if (!info?.isDirectory()) continue;
    const files = await readdir(dir).catch(() => []);
    for (const name of files) {
      if (!ALLOWED_EXT.has(path.extname(name).toLowerCase())) continue;
      const fileInfo = await stat(path.join(dir, name)).catch(() => null);
      if (!fileInfo) continue;
      disk.push({ url: `/uploads/${folder}/${name}`, name, size: fileInfo.size, mtime: fileInfo.mtime });
    }
  }

  // 1) 새 파일 → DB upsert (파일 mtime 유지)
  for (const f of disk) {
    await db.image.upsert({
      where: { url: f.url },
      update: { size: f.size },
      create: {
        url: f.url,
        name: f.name,
        size: f.size,
        mimeType: mimeFromExt(path.extname(f.name)),
        createdAt: f.mtime,
      },
    });
  }

  // 2) DB에 있는데 파일이 없는 레코드 → 정리 (고아)
  const orphanUrls = (await db.image.findMany({ select: { url: true } }))
    .map((i) => i.url)
    .filter((url) => !disk.some((f) => f.url === url));
  if (orphanUrls.length > 0) {
    await db.image.deleteMany({ where: { url: { in: orphanUrls } } });
  }

  // 3) DB 목록 (사용처 포함, 최신순)
  const rows = await db.image.findMany({
    include: { post: { select: { title: true, slug: true } } },
    orderBy: { createdAt: "desc" },
  });
  return rows.map((r) => ({
    url: r.url,
    name: r.name,
    size: r.size,
    date: r.createdAt.toISOString(),
    caption: r.caption,
    postTitle: r.post?.title ?? null,
    postSlug: r.post?.slug ?? null,
  }));
}

function mimeFromExt(ext: string): string {
  switch (ext.toLowerCase()) {
    case ".png": return "image/png";
    case ".jpg": case ".jpeg": return "image/jpeg";
    case ".gif": return "image/gif";
    case ".webp": return "image/webp";
    default: return "application/octet-stream";
  }
}

// 업로드 시 DB 기록
export async function createImage(input: { url: string; name: string; size: number; mimeType: string; caption?: string }) {
  return db.image.upsert({
    where: { url: input.url },
    update: { caption: input.caption ?? null },
    create: {
      url: input.url,
      name: input.name,
      size: input.size,
      mimeType: input.mimeType,
      caption: input.caption ?? null,
    },
  });
}

// 삭제: 파일 + DB
export async function deleteImage(name: string): Promise<boolean> {
  const [folder, file] = name.split("/");
  const target = path.resolve(UPLOAD_ROOT, folder, file);
  if (!target.startsWith(path.resolve(UPLOAD_ROOT) + path.sep)) return false;
  try {
    await unlink(target);
    await db.image.deleteMany({ where: { url: `/uploads/${name}` } });
    return true;
  } catch {
    return false;
  }
}

// 캡션 수정
export async function updateImageCaption(name: string, caption: string | null) {
  return db.image.update({
    where: { url: `/uploads/${name}` },
    data: { caption: caption?.trim() || null },
    include: { post: { select: { title: true, slug: true } } },
  });
}

// 사용처 추적: 본문에서 /uploads/ 참조를 찾아 Image.postId 갱신
export async function trackImageUsage(postId: string, body: string) {
  const refs = new Set<string>();
  const pattern = /\/uploads\/\d{8}\/[\w.-]+\.(png|jpe?g|gif|webp)/gi;
  for (const m of body.matchAll(pattern)) {
    refs.add(m[0].toLowerCase());
  }
  if (refs.size === 0) return;
  await db.image.updateMany({
    where: { url: { in: [...refs] } },
    data: { postId },
  });
}