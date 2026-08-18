// [FEATURE] Auth.js v5 설정 — Google 로그인 (T-04)
import NextAuth from "next-auth";
import Google from "next-auth/providers/google";
import { PrismaAdapter } from "@auth/prisma-adapter";
import { db, prismaBase } from "@/lib/db";
import { logger } from "@/lib/logger";
import { bumpDailyStat, isSameUtcDay } from "@/lib/stats"; // T-59: 일별 통계

declare module "next-auth" {
  interface Session {
    user: {
      id: string;
      role?: string | null;
    } & DefaultSession["user"];
  }
  interface User {
    role?: string | null;
  }
}
import { DefaultSession } from "next-auth";

declare module "@auth/core/jwt" {
  interface JWT {
    role?: string | null;
  }
}

export const { handlers, auth, signIn, signOut } = NextAuth({
  adapter: PrismaAdapter(prismaBase),
  providers: [
    Google({
      clientId: process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    }),
  ],
  session: { strategy: "jwt" },
  callbacks: {
    async signIn({ user }) {
      logger.info("Auth", `로그인: ${user.email ?? user.id}`);
      // T-59: 신규 유저 감지 — PrismaAdapter가 user 생성 후 호출되므로
      // createdAt이 오늘(UTC)이면 오늘 신규 가입으로 집계
      if (user.email) {
        const existing = await db.user.findUnique({ where: { email: user.email } }).catch(() => null);
        if (existing && isSameUtcDay(existing.createdAt, new Date())) {
          bumpDailyStat("newUsers");
        }
      }
      return true;
    },
    async jwt({ token, user }) {
      if (user?.role) token.role = user.role;
      return token;
    },
    async session({ session, token }) {
      if (token.sub && session.user) session.user.id = token.sub;
      if (token.role) session.user.role = token.role;
      return session;
    },
  },
  pages: {
    signIn: "/login",
  },
  trustHost: true,
});