// [FEATURE] 게시글 카드 (목록용) — T-18: 태그 배지 + 상대시간 (iosgods 패턴)
// framer-motion spring (apple-design) + SVG 메타 (이모지 대체)
"use client";

import Link from "next/link";
import { motion, useReducedMotion } from "framer-motion";
import type { PostListItem } from "@/lib/posts";
import { fmtRelativeTime, fmtFullDate } from "@/lib/format";
import { EyeIcon, CommentIcon } from "@/components/Icons";

const MotionLink = motion(Link);

export default function PostCard({ post }: { post: PostListItem }) {
  const reduced = useReducedMotion();
  return (
    <MotionLink
      href={`/post/${post.slug}`}
      className="card block overflow-hidden hover:shadow-md transition-shadow"
      whileHover={reduced ? undefined : { y: -3 }}
      whileTap={reduced ? undefined : { scale: 0.985 }}
      transition={{ type: "spring", bounce: 0, duration: 0.3 }}
    >
      {post.thumbnailUrl && (
        <div className="aspect-video bg-surface overflow-hidden">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={post.thumbnailUrl} alt={post.title} className="w-full h-full object-cover" loading="lazy" />
        </div>
      )}
      <div className="p-4">
        <div className="flex items-center gap-2 text-xs text-text-muted mb-2 flex-wrap">
          {post.categories.slice(0, 2).map((c) => (
            <span key={c.slug} className="badge bg-primary-soft text-primary">
              {c.name}
            </span>
          ))}
          {post.tags.slice(0, 2).map((t) => (
            <span key={t.slug} className="badge bg-surface-hover text-text-secondary">
              #{t.name}
            </span>
          ))}
          <span className="ml-auto shrink-0" title={fmtFullDate(post.publishedAt)}>
            {fmtRelativeTime(post.publishedAt)}
          </span>
        </div>
        <h3 className="font-semibold text-lg leading-snug mb-1 line-clamp-2">{post.title}</h3>
        {post.excerpt && <p className="text-sm text-text-secondary line-clamp-2">{post.excerpt}</p>}
        <div className="flex items-center gap-3 mt-3 text-xs text-text-muted">
          <span className="inline-flex items-center gap-1">
            <EyeIcon className="w-3.5 h-3.5" />
            <span className="tnum">{post.viewCount}</span>
          </span>
          <span className="inline-flex items-center gap-1">
            <CommentIcon className="w-3.5 h-3.5" />
            <span className="tnum">{post.commentCount}</span>
          </span>
        </div>
      </div>
    </MotionLink>
  );
}