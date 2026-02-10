export enum AuthProviderType {
  APPLE = 'APPLE',
  GOOGLE = 'GOOGLE',
  EMAIL = 'EMAIL',
}

export enum SongStatus {
  QUEUED = 'QUEUED',
  DOWNLOADING = 'DOWNLOADING',
  SPLITTING = 'SPLITTING',
  ANALYZING = 'ANALYZING',
  READY = 'READY',
  FAILED = 'FAILED',
}

export enum StemType {
  VOCALS = 'VOCALS',
  INSTRUMENTAL = 'INSTRUMENTAL',
  DRUMS = 'DRUMS',
  BASS = 'BASS',
  OTHER = 'OTHER',
}

export enum ExerciseCategory {
  SCALES = 'SCALES',
  ARPEGGIOS = 'ARPEGGIOS',
  INTERVALS = 'INTERVALS',
  SUSTAINED = 'SUSTAINED',
  VIBRATO = 'VIBRATO',
  CUSTOM = 'CUSTOM',
}
