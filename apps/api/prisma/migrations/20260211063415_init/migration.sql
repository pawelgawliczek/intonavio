-- CreateEnum
CREATE TYPE "AuthProviderType" AS ENUM ('APPLE', 'GOOGLE', 'EMAIL');

-- CreateEnum
CREATE TYPE "SongStatus" AS ENUM ('QUEUED', 'DOWNLOADING', 'SPLITTING', 'ANALYZING', 'READY', 'FAILED');

-- CreateEnum
CREATE TYPE "ExerciseCategory" AS ENUM ('SCALES', 'ARPEGGIOS', 'INTERVALS', 'SUSTAINED', 'VIBRATO', 'CUSTOM');

-- CreateEnum
CREATE TYPE "StemType" AS ENUM ('VOCALS', 'INSTRUMENTAL', 'DRUMS', 'BASS', 'OTHER');

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT,
    "displayName" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AuthProvider" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "provider" "AuthProviderType" NOT NULL,
    "providerId" TEXT NOT NULL,
    "passwordHash" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AuthProvider_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Song" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "videoId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "thumbnailUrl" TEXT NOT NULL,
    "duration" INTEGER NOT NULL,
    "status" "SongStatus" NOT NULL DEFAULT 'QUEUED',
    "externalJobId" TEXT,
    "errorMessage" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Song_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UserSongLibrary" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "songId" TEXT NOT NULL,
    "addedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UserSongLibrary_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Stem" (
    "id" TEXT NOT NULL,
    "songId" TEXT NOT NULL,
    "type" "StemType" NOT NULL,
    "storageKey" TEXT NOT NULL,
    "format" TEXT NOT NULL DEFAULT 'mp3',
    "fileSize" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Stem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PitchData" (
    "id" TEXT NOT NULL,
    "songId" TEXT,
    "exerciseId" TEXT,
    "storageKey" TEXT NOT NULL,
    "frameCount" INTEGER NOT NULL,
    "hopDuration" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PitchData_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Session" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "songId" TEXT NOT NULL,
    "duration" INTEGER NOT NULL,
    "loopStart" DOUBLE PRECISION,
    "loopEnd" DOUBLE PRECISION,
    "speed" DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    "overallScore" DOUBLE PRECISION NOT NULL,
    "pitchLog" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Session_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Exercise" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "category" "ExerciseCategory" NOT NULL,
    "key" TEXT NOT NULL,
    "startOctave" INTEGER NOT NULL DEFAULT 4,
    "tempo" DOUBLE PRECISION NOT NULL DEFAULT 60.0,
    "notes" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Exercise_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ExerciseAttempt" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "exerciseId" TEXT NOT NULL,
    "speed" DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    "overallScore" DOUBLE PRECISION NOT NULL,
    "pitchLog" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ExerciseAttempt_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "AuthProvider_userId_idx" ON "AuthProvider"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "AuthProvider_provider_providerId_key" ON "AuthProvider"("provider", "providerId");

-- CreateIndex
CREATE UNIQUE INDEX "Song_videoId_key" ON "Song"("videoId");

-- CreateIndex
CREATE INDEX "Song_userId_idx" ON "Song"("userId");

-- CreateIndex
CREATE INDEX "Song_status_idx" ON "Song"("status");

-- CreateIndex
CREATE INDEX "UserSongLibrary_userId_idx" ON "UserSongLibrary"("userId");

-- CreateIndex
CREATE INDEX "UserSongLibrary_songId_idx" ON "UserSongLibrary"("songId");

-- CreateIndex
CREATE UNIQUE INDEX "UserSongLibrary_userId_songId_key" ON "UserSongLibrary"("userId", "songId");

-- CreateIndex
CREATE UNIQUE INDEX "Stem_songId_type_key" ON "Stem"("songId", "type");

-- CreateIndex
CREATE UNIQUE INDEX "PitchData_songId_key" ON "PitchData"("songId");

-- CreateIndex
CREATE UNIQUE INDEX "PitchData_exerciseId_key" ON "PitchData"("exerciseId");

-- CreateIndex
CREATE INDEX "Session_userId_idx" ON "Session"("userId");

-- CreateIndex
CREATE INDEX "Session_songId_idx" ON "Session"("songId");

-- CreateIndex
CREATE INDEX "Session_createdAt_idx" ON "Session"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "Exercise_name_key_startOctave_key" ON "Exercise"("name", "key", "startOctave");

-- CreateIndex
CREATE INDEX "ExerciseAttempt_userId_idx" ON "ExerciseAttempt"("userId");

-- CreateIndex
CREATE INDEX "ExerciseAttempt_exerciseId_idx" ON "ExerciseAttempt"("exerciseId");

-- CreateIndex
CREATE INDEX "ExerciseAttempt_createdAt_idx" ON "ExerciseAttempt"("createdAt");

-- AddForeignKey
ALTER TABLE "AuthProvider" ADD CONSTRAINT "AuthProvider_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Song" ADD CONSTRAINT "Song_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserSongLibrary" ADD CONSTRAINT "UserSongLibrary_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserSongLibrary" ADD CONSTRAINT "UserSongLibrary_songId_fkey" FOREIGN KEY ("songId") REFERENCES "Song"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Stem" ADD CONSTRAINT "Stem_songId_fkey" FOREIGN KEY ("songId") REFERENCES "Song"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PitchData" ADD CONSTRAINT "PitchData_songId_fkey" FOREIGN KEY ("songId") REFERENCES "Song"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PitchData" ADD CONSTRAINT "PitchData_exerciseId_fkey" FOREIGN KEY ("exerciseId") REFERENCES "Exercise"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Session" ADD CONSTRAINT "Session_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Session" ADD CONSTRAINT "Session_songId_fkey" FOREIGN KEY ("songId") REFERENCES "Song"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ExerciseAttempt" ADD CONSTRAINT "ExerciseAttempt_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ExerciseAttempt" ADD CONSTRAINT "ExerciseAttempt_exerciseId_fkey" FOREIGN KEY ("exerciseId") REFERENCES "Exercise"("id") ON DELETE CASCADE ON UPDATE CASCADE;
