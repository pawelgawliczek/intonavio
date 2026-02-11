export interface SessionResponse {
  readonly id: string;
  readonly songId: string;
  readonly duration: number;
  readonly loopStart: number | null;
  readonly loopEnd: number | null;
  readonly speed: number;
  readonly overallScore: number;
  readonly createdAt: Date;
}

export interface SessionDetailResponse extends SessionResponse {
  readonly pitchLog: unknown;
}
