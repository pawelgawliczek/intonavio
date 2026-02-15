export interface PitchFrame {
  t: number;
  hz: number | null;
  midi: number | null;
  voiced: boolean;
}

export interface Phrase {
  index: number;
  startFrame: number;
  endFrame: number;
  startTime: number;
  endTime: number;
  voicedFrameCount: number;
}

export interface PitchDataFile {
  songId?: string;
  exerciseId?: string;
  sampleRate: number;
  hopSize: number;
  hopDuration: number;
  frameCount: number;
  frames: PitchFrame[];
  phrases: Phrase[];
}
