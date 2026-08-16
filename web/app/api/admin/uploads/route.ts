// POST /api/admin/uploads — 이미지 업로드 (관리자 전용, DB 기록 + 캡션)
// GET /api/admin/uploads — 이미지 목록 (파일↔DB sync, 최신순, 사용처 포함)
// DELETE /api/admin/uploads?name=YYYYMMDD/파일.ext — 이미지 삭제 (파일 + DB)
// PATCH /api/admin/uploads?name=YYYYMMDD/파일.ext — 캡션 수정
// 로컬 저장: public/uploads/YYYYMMDD/uuid.ext (dev용 — Vercel 배포 시 R2로 대체, T-08)
import { mkdir, writeFile } from "fs/promises";
import path from "path";
import { getAdminUser } from "@/lib/admin";
import { apiError, apiOk } from "@/lib/api";
import { logger } from "@/lib/logger";
import { listImages, createImage, deleteImage, updateImageCaption } from "@/lib/image";

export const runtime = "nodejs";

const ALLOWED = new Map<string, string>([
  ["image/png", ".png"],
  ["image/jpeg", ".jpg"],
  ["image/gif", ".gif"],
  ["image/webp", ".webp"],
]);
const MAX_SIZE = 5 * 1024 * 1024; // 5MB

export async function POST(req: Request) {
  const pathname = "/api/admin/uploads";
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "POST", path: pathname });
  }
  let form: FormData;
  try {
    form = await req.formData();
  } catch {
    return apiError("E-WEB-VALID-1001", 400, { method: "POST", path: pathname });
  }
  const file = form.get("file");
  if (!(file instanceof File)) {
    return apiError("E-WEB-VALID-1001", 400, { method: "POST", path: pathname });
  }
  if (file.size > MAX_SIZE) {
    return apiError("E-WEB-UPLOAD-1001", 400, { method: "POST", path: pathname });
  }
  const ext = ALLOWED.get(file.type);
  if (!ext) {
    return apiError("E-WEB-UPLOAD-1002", 400, { method: "POST", path: pathname });
  }
  try {
    const day = new Date().toISOString().slice(0, 10).replace(/-/g, "");
    const name = `${crypto.randomUUID()}${ext}`;
    const dir = path.join(process.cwd(), "public", "uploads", day);
    await mkdir(dir, { recursive: true });
    await writeFile(path.join(dir, name), Buffer.from(await file.arrayBuffer()));
    const url = `/uploads/${day}/${name}`;
    const caption = typeof form.get("caption") === "string" ? String(form.get("caption")).trim() : "";
    await createImage({ url, name, size: file.size, mimeType: file.type, caption: caption || undefined });
    logger.info("Upload", `이미지 업로드 완료 (${file.type}, ${file.size} bytes)`, { url });
    return apiOk({ url, size: file.size, type: file.type, caption: caption || null }, { method: "POST", path: pathname });
  } catch (err) {
    logger.error("Upload", `저장 실패: ${err instanceof Error ? err.message : err}`);
    return apiError("E-WEB-NET-1001", 500, { method: "POST", path: pathname });
  }
}

// 이미지 목록 (파일↔DB sync 후 반환)
export async function GET(req: Request) {
  const pathname = "/api/admin/uploads";
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "GET", path: pathname });
  }
  try {
    const images = await listImages();
    logger.info("Upload", `이미지 목록 조회 (${images.length}개)`);
    return apiOk({ images }, { method: "GET", path: pathname });
  } catch (err) {
    logger.error("Upload", `목록 조회 실패: ${err instanceof Error ? err.message : err}`);
    return apiError("E-WEB-NET-1001", 500, { method: "GET", path: pathname });
  }
}

// 이미지 삭제 (파일 + DB, 경로 트래버설 방지)
export async function DELETE(req: Request) {
  const pathname = "/api/admin/uploads";
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "DELETE", path: pathname });
  }
  const url = new URL(req.url);
  const name = url.searchParams.get("name") ?? "";
  if (!name || !/^\d{8}\/[\w.-]+\.(png|jpe?g|gif|webp)$/i.test(name)) {
    return apiError("E-WEB-VALID-1002", 400, { method: "DELETE", path: pathname });
  }
  const ok = await deleteImage(name);
  if (!ok) {
    return apiError("E-WEB-UPLOAD-1003", 404, { method: "DELETE", path: pathname });
  }
  logger.info("Upload", `이미지 삭제 완료 (${name})`);
  return apiOk({ deleted: name }, { method: "DELETE", path: pathname });
}

// 캡션 수정
export async function PATCH(req: Request) {
  const pathname = "/api/admin/uploads";
  if (!(await getAdminUser(req))) {
    return apiError("E-WEB-AUTH-1001", 401, { method: "PATCH", path: pathname });
  }
  const url = new URL(req.url);
  const name = url.searchParams.get("name") ?? "";
  if (!name || !/^\d{8}\/[\w.-]+\.(png|jpe?g|gif|webp)$/i.test(name)) {
    return apiError("E-WEB-VALID-1002", 400, { method: "PATCH", path: pathname });
  }
  const body = (await req.json().catch(() => null)) as { caption?: string };
  try {
    const updated = await updateImageCaption(name, body?.caption ?? "");
    logger.info("Upload", `캡션 수정 (${name})`);
    return apiOk({
      url: updated.url,
      caption: updated.caption,
      postTitle: updated.post?.title ?? null,
    }, { method: "PATCH", path: pathname });
  } catch {
    return apiError("E-WEB-UPLOAD-1003", 404, { method: "PATCH", path: pathname });
  }
}