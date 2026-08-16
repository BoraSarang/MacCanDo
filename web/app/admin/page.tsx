// [FEATURE] /admin 페이지 — 관리자 전용 (T-05)
// role === ADMIN 사용자만 접근, 아니면 안내
import { getAdminUser } from "@/lib/admin";
import AdminDashboard from "@/components/admin/AdminDashboard";
import { logger } from "@/lib/logger";

export const metadata = { title: "관리자 대시보드" };

export default async function AdminPage() {
  const admin = await getAdminUser();
  if (!admin) {
    logger.info("Admin", "비관리자 접근 페이지 표시");
    return (
      <div className="text-center py-16">
        <h1 className="text-2xl font-bold mb-3">관리자 전용</h1>
        <p className="text-text-secondary">관리자 계정으로 로그인한 경우에만 접근할 수 있습니다.</p>
      </div>
    );
  }

  return <AdminDashboard />;
}