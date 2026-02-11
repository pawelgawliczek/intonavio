export interface VerifiedIdentity {
  providerId: string;
  email?: string;
  displayName?: string;
}

export interface ExternalAuthProvider {
  verify(token: string, ...args: unknown[]): Promise<VerifiedIdentity>;
}
