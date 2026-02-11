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
