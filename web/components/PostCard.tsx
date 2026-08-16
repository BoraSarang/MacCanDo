// [FEATURE] 게시글 카드 (목록용)
import Link from "next/link";
import type { PostListItem } from "@/lib/posts";

function formatDate(d: Date | null) {
  if (!d) return "";
  return new Intl.DateTimeFormat("ko-KR", { dateStyle: "medium" }).format(d);
}

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
        <div className="flex items-center gap-2 text-xs text-text-muted mb-2">
          {post.category && (
            <Link
              href={`/category/${post.category.slug}`}
              className="badge bg-primary-soft text-primary"
            >
              {post.category.name}
            </Link>
          )}
          <span>{formatDate(post.publishedAt)}</span>
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