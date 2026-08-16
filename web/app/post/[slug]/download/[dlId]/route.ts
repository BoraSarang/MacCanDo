// [FEATURE] 다운로드 게이트 라우트 — T-05
// GET /post/[slug]/download/[dlId] — 게이트 판정 후 외부 링크로 302 리다이렉트 + 클릭 기록
import { NextResponse } from "next/server";
import { checkDownloadGate, recordDownloadEvent } from "@/lib/downloads";
import { auth } from "@/auth";
import { logger } from "@/lib/logger";

interface Params {
  params: Promise<{ slug: string; dlId: string }>;
}

export async function GET(_req: Request, { params }: Params) {
  const { slug, dlId } = await params;
  const session = await auth();
  const userId = session?.user?.id;
  const ip = _req.headers.get("x-forwarded-for")?.split(",")[0]?.trim();

  logger.info("Download", `요청 (slug=${slug}, link=${dlId}, user=${userId ?? "-"})`);

  const gate = await checkDownloadGate(dlId, userId);
  if (!gate.ok) {
    return NextResponse.redirect(new URL(`/post/${slug}?gate=blocked`, _req.url));
  }

  await recordDownloadEvent({
    linkId: dlId,
    postId: gate.link.postId,
    userId,
    ip,
  });

  return NextResponse.redirect(gate.link.url, 302);
}