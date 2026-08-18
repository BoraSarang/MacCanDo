// [FEATURE] 인라인 SVG 아이콘 — 이모지 대체 시각 언어 (apple-design 스타일, stroke=currentColor)
type IconProps = { className?: string };

function base(className?: string) {
  return {
    className: className ?? "w-4 h-4",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: 1.8,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
    viewBox: "0 0 24 24",
    "aria-hidden": true,
  };
}

export function SunIcon({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <circle cx="12" cy="12" r="4.5" />
      <path d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M4.9 4.9l1.6 1.6M17.5 17.5l1.6 1.6M19.1 4.9l-1.6 1.6M6.5 17.5l-1.6 1.6" />
    </svg>
  );
}

export function MoonIcon({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <path d="M20 13.5A8 8 0 0 1 10.5 4a8 8 0 1 0 9.5 9.5Z" />
    </svg>
  );
}

export function EyeIcon({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  );
}

export function CommentIcon({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <path d="M21 12a8 8 0 0 1-8 8H4l2.2-3.4A8 8 0 1 1 21 12Z" />
    </svg>
  );
}

export function SearchIcon({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <circle cx="11" cy="11" r="6.5" />
      <path d="m16 16 4.5 4.5" />
    </svg>
  );
}

export function MenuIcon({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <path d="M4 7h16M4 12h16M4 17h16" />
    </svg>
  );
}

export function MoreIcon({ className }: IconProps) {
  return (
    <svg {...base(className)}>
      <circle cx="5.5" cy="12" r="1" fill="currentColor" />
      <circle cx="12" cy="12" r="1" fill="currentColor" />
      <circle cx="18.5" cy="12" r="1" fill="currentColor" />
    </svg>
  );
}