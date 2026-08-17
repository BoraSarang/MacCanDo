// [FEATURE] 푸터 — 사이트 링크 (정적 페이지, T-17)
// 데스크톱: 가로 한 줄 / 모바일: 세로 정렬
import Link from "next/link";

const PAGE_LINKS = [
  { href: "/post/about", label: "About" },
  { href: "/post/privacy-policy", label: "Privacy Policy" },
  { href: "/post/disclaimer", label: "Disclaimer" },
  { href: "/post/terms", label: "Terms of Service" },
  { href: "/post/faq", label: "FAQ" },
  { href: "/post/contact", label: "Contact Us" },
];

export default function Footer() {
  return (
    <footer className="border-t border-border py-6 text-center text-sm text-text-muted">
      <nav
        className="flex flex-col items-center gap-2 md:flex-row md:justify-center md:gap-6 md:mb-2 pb-4 md:pb-0"
        aria-label="사이트 정보"
      >
        {PAGE_LINKS.map((l) => (
          <Link key={l.href} href={l.href} className="hover:text-primary transition-colors">
            {l.label}
          </Link>
        ))}
      </nav>
      <p>© 2026 MacCanDo — 맥으로 이것도 할 수 있다</p>
    </footer>
  );
}
