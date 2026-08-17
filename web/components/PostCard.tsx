// [FEATURE] 게시글 카드 (목록용) — T-18: 태그 배지 + 상대시간 (iosgods 패턴)
import Link from "next/link";
import type { PostListItem } from "@/lib/posts";
import { fmtRelativeTime, fmtFullDate } from "@/lib/format";

export default function PostCard({ post }: { post: PostListItem }) {
  return (
    <Link
      href={`/post/${post.slug}`}
      className="card block overflow-hidden hover:shadow-md transition-shadow"
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
            <Link key={c.slug} href={`/category/${c.slug}`} className="badge bg-primary-soft text-primary">
              {c.name}
            </Link>
          ))}
          {post.tags.slice(0, 2).map((t) => (
            <Link key={t.slug} href={`/tag/${t.slug}`} className="badge bg-surface-hover text-text-secondary hover:text-primary">
              #{t.name}
            </Link>
          ))}
          <span className="ml-auto shrink-0" title={fmtFullDate(post.publishedAt)}>
            {fmtRelativeTime(post.publishedAt)}
          </span>
        </div>
        <h3 className="font-semibold text-lg leading-snug mb-1 line-clamp-2">{post.title}</h3>
        {post.excerpt && <p className="text-sm text-text-secondary line-clamp-2">{post.excerpt}</p>}
        <div className="flex items-center gap-3 mt-3 text-xs text-text-muted">
          <span>👁 {post.viewCount}</span>
          <span>💬 {post.commentCount}</span>
        </div>
      </div>
    </Link>
  );
}