// [FEATURE] 다크모드 테마 프로바이더 — T-05b
// 시스템 설정 자동 감지 + 수동 토글 (localStorage: macando-theme)
"use client";

import { useEffect, useState, createContext, useContext } from "react";

const ThemeContext = createContext<{ dark: boolean; toggle: () => void }>({
  dark: false,
  toggle: () => {},
});

export const useTheme = () => useContext(ThemeContext);

export default function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [dark, setDark] = useState(false);

  useEffect(() => {
    const stored = localStorage.getItem("maccando-theme");
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    const initial = stored ? stored === "dark" : prefersDark;
    requestAnimationFrame(() => {
      setDark(initial);
      document.documentElement.classList.toggle("dark", initial);
    });
  }, []);

  const toggle = () => {
    setDark((prev) => {
      const next = !prev;
      document.documentElement.classList.toggle("dark", next);
      localStorage.setItem("maccando-theme", next ? "dark" : "light");
      return next;
    });
  };

  return <ThemeContext.Provider value={{ dark, toggle }}>{children}</ThemeContext.Provider>;
}