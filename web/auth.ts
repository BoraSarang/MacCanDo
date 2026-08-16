// [FEATURE] Auth.js v5 설정 — Google 로그인 (T-04)
import NextAuth from "next-auth";
import Google from "next-auth/providers/google";
import { PrismaAdapter } from "@auth/prisma-adapter";
import { prismaBase } from "@/lib/db";
import { logger } from "@/lib/logger";

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