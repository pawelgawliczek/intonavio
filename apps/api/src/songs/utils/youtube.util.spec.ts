import { buildThumbnailUrl, extractVideoId } from './youtube.util';

describe('extractVideoId', () => {
  it.each([
    ['https://www.youtube.com/watch?v=dQw4w9WgXcQ', 'dQw4w9WgXcQ'],
    ['https://youtube.com/watch?v=dQw4w9WgXcQ', 'dQw4w9WgXcQ'],
    ['https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30', 'dQw4w9WgXcQ'],
    ['https://youtu.be/dQw4w9WgXcQ', 'dQw4w9WgXcQ'],
    ['https://www.youtube.com/shorts/dQw4w9WgXcQ', 'dQw4w9WgXcQ'],
    ['https://www.youtube.com/embed/dQw4w9WgXcQ', 'dQw4w9WgXcQ'],
    ['https://youtube.com/watch?v=dQw4w9WgXcQ&list=PLtest', 'dQw4w9WgXcQ'],
  ])('should extract videoId from %s', (url, expected) => {
    expect(extractVideoId(url)).toBe(expected);
  });

  it.each(['https://example.com/video', 'not-a-url', 'https://youtube.com/playlist?list=abc', ''])(
    'should return null for invalid URL: %s',
    (url) => {
      expect(extractVideoId(url)).toBeNull();
    },
  );
});

describe('buildThumbnailUrl', () => {
  it('should build maxresdefault thumbnail URL', () => {
    expect(buildThumbnailUrl('dQw4w9WgXcQ')).toBe(
      'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
    );
  });
});
