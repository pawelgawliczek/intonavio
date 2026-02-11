import type { AuthProviderType, ExerciseCategory, SongStatus, StemType } from './enums';

export interface User {
  id: string;
  email: string | null;
  displayName: string;
  createdAt: string;
  updatedAt: string;
}

export interface Song {
  id: string;
  userId: string;
  videoId: string;
  title: string;
  thumbnailUrl: string;
  duration: number;
  status: SongStatus;
  externalJobId: string | null;
  errorMessage: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface Stem {
  id: string;
  songId: string;
  type: StemType;
  storageKey: string;
  format: string;
  fileSize: number;
  createdAt: string;
}

export interface PitchData {
  id: string;
  songId: string | null;
  exerciseId: string | null;
  storageKey: string;
  frameCount: number;
  hopDuration: number;
  createdAt: string;
}

export interface Session {
  id: string;
  userId: string;
  songId: string;
  duration: number;
  loopStart: number | null;
  loopEnd: number | null;
  speed: number;
  overallScore: number;
  pitchLog: PitchLogEntry[];
  createdAt: string;
}

export interface Exercise {
  id: string;
  name: string;
  category: ExerciseCategory;
  key: string;
  startOctave: number;
  tempo: number;
  notes: ExerciseNote[];
  createdAt: string;
}

export interface ExerciseNote {
  midi: number;
  duration: number;
  rest: number;
  vibrato?: {
    cents: number;
    rateHz: number;
  };
}

export interface ExerciseAttempt {
  id: string;
  userId: string;
  exerciseId: string;
  speed: number;
  overallScore: number;
  pitchLog: PitchLogEntry[];
  createdAt: string;
}

export interface PitchLogEntry {
  time: number;
  detectedHz: number | null;
  referenceHz: number | null;
  cents: number | null;
}

export interface AuthProvider {
  id: string;
  userId: string;
  provider: AuthProviderType;
  providerId: string;
  createdAt: string;
}

export interface UserSongLibrary {
  id: string;
  userId: string;
  songId: string;
  addedAt: string;
}
