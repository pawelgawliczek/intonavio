export const TEST_SONG_ID = 'cm1234567890abcdefghijklm';
export const TEST_STEM_ID = 'cm9876543210zyxwvutsrqpon';

export const SONG_QUEUED = {
  id: TEST_SONG_ID,
  videoId: 'dQw4w9WgXcQ',
  title: 'Test Song',
  thumbnailUrl: 'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
  duration: 213,
  status: 'QUEUED',
  stems: [],
  pitchData: null,
  createdAt: new Date('2025-06-01T12:00:00Z'),
};

export const SONG_READY = {
  ...SONG_QUEUED,
  status: 'READY',
  stems: [
    { id: TEST_STEM_ID, type: 'VOCALS', storageKey: 'stems/song-1/vocals.mp3', format: 'mp3' },
    {
      id: 'cm0000000000aaaaaaaaaaaaa',
      type: 'DRUMS',
      storageKey: 'stems/song-1/drums.mp3',
      format: 'mp3',
    },
    {
      id: 'cm0000000000bbbbbbbbbbbbb',
      type: 'BASS',
      storageKey: 'stems/song-1/bass.mp3',
      format: 'mp3',
    },
    {
      id: 'cm0000000000ccccccccccccc',
      type: 'OTHER',
      storageKey: 'stems/song-1/other.mp3',
      format: 'mp3',
    },
  ],
  pitchData: { id: 'cm0000000000ddddddddddddd', storageKey: 'pitch/song-1/reference.json' },
};

export const STEM_PRESIGNED = {
  url: 'https://r2.example.com/presigned-url',
  expiresIn: 900,
};
