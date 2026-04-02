import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

import { Logger } from '@nestjs/common';

const execFileAsync = promisify(execFile);
const logger = new Logger('YouTubeSearch');

export interface YouTubeSearchResult {
  videoId: string;
  title: string;
  artist: string;
  duration: number;
  thumbnailUrl: string;
  url: string;
  hasLyrics: boolean;
}

interface YtDlpEntry {
  id: string;
  title: string;
  channel: string;
  uploader: string;
  duration: number;
  thumbnails: { url: string; height?: number; width?: number }[];
  url: string;
  webpage_url: string;
}

export async function searchYouTube(query: string, limit: number): Promise<YouTubeSearchResult[]> {
  const { stdout } = await execFileAsync(
    'yt-dlp',
    [
      `ytsearch${limit}:${query}`,
      '--dump-json',
      '--flat-playlist',
      '--no-download',
      '--no-warnings',
    ],
    { timeout: 15_000, maxBuffer: 1024 * 1024 },
  );

  const entries = stdout
    .trim()
    .split('\n')
    .filter(Boolean)
    .map((line) => JSON.parse(line) as YtDlpEntry);

  const results = await Promise.all(
    entries.map(async (entry) => {
      const hasLyrics = await checkLRCLib(entry.title, entry.channel || entry.uploader);

      return {
        videoId: entry.id,
        title: entry.title,
        artist: entry.channel || entry.uploader || '',
        duration: Math.round(entry.duration ?? 0),
        thumbnailUrl: pickThumbnail(entry),
        url: entry.webpage_url || entry.url,
        hasLyrics,
      };
    }),
  );

  return results;
}

function pickThumbnail(entry: YtDlpEntry): string {
  if (entry.thumbnails?.length) {
    const best = entry.thumbnails.reduce((a, b) => ((b.width ?? 0) > (a.width ?? 0) ? b : a));
    return best.url;
  }
  return `https://img.youtube.com/vi/${entry.id}/hqdefault.jpg`;
}

interface LRCLibSearchResult {
  syncedLyrics: string | null;
  trackName: string;
  artistName: string;
}

export async function checkLyricsAvailable(title: string, artist: string): Promise<boolean> {
  return checkLRCLib(title, artist);
}

async function checkLRCLib(title: string, artist: string): Promise<boolean> {
  const cleanedTitle = cleanYouTubeTitle(title);
  const query = [cleanedTitle, artist].filter(Boolean).join(' ');

  try {
    const url = `https://lrclib.net/api/search?q=${encodeURIComponent(query)}`;
    const response = await fetch(url, { signal: AbortSignal.timeout(3000) });
    if (!response.ok) return false;

    const results = (await response.json()) as LRCLibSearchResult[];
    return results.some((r) => r.syncedLyrics != null && r.syncedLyrics.length > 0);
  } catch {
    logger.debug(`LRCLIB check failed for "${query}"`);
    return false;
  }
}

const YOUTUBE_TITLE_NOISE_STRINGS = [
  '(Official Music Video)',
  '(Official Video)',
  '(Official Audio)',
  '(Official Lyric Video)',
  '(Official Lyrics Video)',
  '(Lyrics)',
  '(Lyric Video)',
  '(Music Video)',
  '(Audio)',
  '(Visualizer)',
  '(Live)',
  '[Official Music Video]',
  '[Official Video]',
  '[Official Audio]',
  '[Lyrics]',
  '[Lyric Video]',
  '[Music Video]',
  '[Audio]',
  '[Visualizer]',
  '[Live]',
];

function cleanYouTubeTitle(title: string): string {
  let cleaned = title;
  for (const noise of YOUTUBE_TITLE_NOISE_STRINGS) {
    const index = cleaned.toLowerCase().indexOf(noise.toLowerCase());
    if (index !== -1) {
      cleaned = cleaned.slice(0, index) + cleaned.slice(index + noise.length);
    }
  }
  return cleaned.trim();
}
