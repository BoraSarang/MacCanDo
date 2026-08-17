// MacCanDo 루트 레이아웃 — 헤더(로고/네비/검색) + 푸터
import type { Metadata } from "next";
import "./globals.css";
import { SessionProvider } from "next-auth/react";
import Header from "@/components/Header";
import Footer from "@/components/Footer";
import MobileBar from "@/components/MobileBar";
import ThemeProvider from "@/components/ThemeProvider";

export const metadata: Metadata = {
  title: {
    default: "MacCanDo — 맥으로 이것도 할 수 있다",
    template: "%s | MacCanDo",
  },
  description:
    "Mac 유용한 프로그램 소개, 꿀팁 가이드, 유틸리티 큐레이션 — 맥으로 이것도 할 수 있다",
  keywords: ["Mac", "맥", "macOS", "유틸리티", "앱 추천", "맥 팁"],
  openGraph: {
    title: "MacCanDo",
    description: "맥으로 이것도 할 수 있다",
    type: "website",
    locale: "ko_KR",
  },
  robots: { index: true, follow: true },
};

// FOUC 방지 — 첫 렌더 전 테마 적용
const themeScript = `
(function () {
  try {
    var s = localStorage.getItem("maccando-theme");
    var dark = s ? s === "dark" : window.matchMedia("(prefers-color-scheme: dark)").matches;
    if (dark) document.documentElement.classList.add("dark");
  } catch (e) {}
})();
`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
      </head>
      <body className="min-h-screen flex flex-col bg-bg text-text">
        <SessionProvider>
          <ThemeProvider>
            <Header />
            <main className="flex-1 max-w-5xl w-full mx-auto px-4 py-8">{children}</main>
            <Footer />
            <MobileBar />
          </ThemeProvider>
        </SessionProvider>
      </body>
    </html>
  );
}