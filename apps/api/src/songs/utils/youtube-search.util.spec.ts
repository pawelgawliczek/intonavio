import { checkLyricsAvailable } from './youtube-search.util';

const mockFetch = jest.fn();

function makeResponse(results: { syncedLyrics: string | null }[]): Response {
  return {
    ok: true,
    json: async () => results,
  } as Response;
}

describe('youtube-search util', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    global.fetch = mockFetch as unknown as typeof fetch;
  });

  describe('checkLyricsAvailable', () => {
    it('returns true when the title and artist query has synced lyrics', async () => {
      mockFetch.mockResolvedValueOnce(makeResponse([{ syncedLyrics: '[00:01.00]Hello' }]));

      await expect(checkLyricsAvailable('Adele - Hello (Official Video)', 'Adele')).resolves.toBe(
        true,
      );

      expect(mockFetch).toHaveBeenCalledTimes(1);
      expect(mockFetch.mock.calls[0][0]).toContain('Adele%20-%20Hello%20Adele');
    });

    it('tries an artist-title query parsed from the cleaned title', async () => {
      mockFetch
        .mockResolvedValueOnce(makeResponse([{ syncedLyrics: null }]))
        .mockResolvedValueOnce(makeResponse([{ syncedLyrics: '[00:01.00]Hello' }]));

      await expect(
        checkLyricsAvailable('Adele - Hello (Official Video)', 'Random Channel'),
      ).resolves.toBe(true);

      expect(mockFetch).toHaveBeenCalledTimes(2);
      expect(mockFetch.mock.calls[1][0]).toContain('Adele%20Hello');
    });

    it('deduplicates fallback title queries', async () => {
      mockFetch.mockResolvedValueOnce(makeResponse([{ syncedLyrics: null }]));

      await expect(checkLyricsAvailable('Hello (Lyrics)', '')).resolves.toBe(false);

      expect(mockFetch).toHaveBeenCalledTimes(1);
      expect(mockFetch.mock.calls[0][0]).toContain('Hello');
    });
  });
});
