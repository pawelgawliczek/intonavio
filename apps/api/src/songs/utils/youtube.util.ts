const YOUTUBE_PATTERNS: readonly { regex: RegExp; group: number }[] = [
  { regex: /youtube\.com\/watch\?.*v=([a-zA-Z0-9_-]{11})/, group: 1 },
  { regex: /youtu\.be\/([a-zA-Z0-9_-]{11})/, group: 1 },
  { regex: /youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})/, group: 1 },
  { regex: /youtube\.com\/embed\/([a-zA-Z0-9_-]{11})/, group: 1 },
];

export function extractVideoId(url: string): string | null {
  for (const { regex, group } of YOUTUBE_PATTERNS) {
    const match = url.match(regex);
    if (match?.[group]) {
      return match[group];
    }
  }
  return null;
}

export function buildThumbnailUrl(videoId: string): string {
  return `https://img.youtube.com/vi/${videoId}/maxresdefault.jpg`;
}

interface YouTubeMetadata {
  title: string;
  artist: string;
  thumbnailUrl: string;
}

interface OEmbedResponse {
  title?: string;
  author_name?: string;
  thumbnail_url?: string;
}

export async function fetchYouTubeMetadata(videoId: string): Promise<YouTubeMetadata | null> {
  const url = `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${videoId}&format=json`;
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(5000) });
    if (!response.ok) {
      return null;
    }
    const data = (await response.json()) as OEmbedResponse;
    return {
      title: data.title ?? videoId,
      artist: data.author_name ?? '',
      thumbnailUrl: data.thumbnail_url ?? buildThumbnailUrl(videoId),
    };
  } catch {
    return null;
  }
}

const THUMBNAIL_VARIANTS = ['maxresdefault.jpg', 'hqdefault.jpg', 'mqdefault.jpg'] as const;

export async function fetchBestThumbnailUrl(videoId: string): Promise<string> {
  for (const variant of THUMBNAIL_VARIANTS) {
    const url = `https://img.youtube.com/vi/${videoId}/${variant}`;
    try {
      const response = await fetch(url, {
        method: 'HEAD',
        signal: AbortSignal.timeout(3000),
      });
      if (response.ok) {
        return url;
      }
    } catch {
      continue;
    }
  }
  return buildThumbnailUrl(videoId);
}
