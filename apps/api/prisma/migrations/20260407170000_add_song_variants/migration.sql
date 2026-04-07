-- CreateEnum
CREATE TYPE "StemSource" AS ENUM ('STUDIO', 'DRAFT');

-- CreateEnum
CREATE TYPE "VariantStatus" AS ENUM ('QUEUED', 'SPLITTING', 'ANALYZING', 'READY', 'FAILED');

-- AlterTable
ALTER TABLE "Song" ADD COLUMN "activeVariantId" TEXT;

-- CreateTable
CREATE TABLE "SongVariant" (
    "id" TEXT NOT NULL,
    "songId" TEXT NOT NULL,
    "source" "StemSource" NOT NULL,
    "status" "VariantStatus" NOT NULL DEFAULT 'QUEUED',
    "stemsPrefix" TEXT NOT NULL,
    "pitchKey" TEXT,
    "frameCount" INTEGER,
    "hopDuration" DOUBLE PRECISION,
    "externalJobId" TEXT,
    "errorMessage" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SongVariant_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "SongVariant_songId_source_key" ON "SongVariant"("songId", "source");

-- CreateIndex
CREATE INDEX "SongVariant_songId_idx" ON "SongVariant"("songId");

-- CreateIndex
CREATE INDEX "SongVariant_status_idx" ON "SongVariant"("status");

-- CreateIndex
CREATE UNIQUE INDEX "Song_activeVariantId_key" ON "Song"("activeVariantId");

-- AddForeignKey
ALTER TABLE "SongVariant" ADD CONSTRAINT "SongVariant_songId_fkey" FOREIGN KEY ("songId") REFERENCES "Song"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Song" ADD CONSTRAINT "Song_activeVariantId_fkey" FOREIGN KEY ("activeVariantId") REFERENCES "SongVariant"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Backfill: every existing song gets one STUDIO variant pointing at its current
-- stems and pitch data. New songs created from this point on will follow the
-- variant flow normally.
INSERT INTO "SongVariant" ("id", "songId", "source", "status", "stemsPrefix", "pitchKey", "frameCount", "hopDuration", "externalJobId", "errorMessage", "createdAt", "updatedAt")
SELECT
    'sv_' || substr(md5(random()::text || s."id"), 1, 22) AS id,
    s."id" AS "songId",
    'STUDIO'::"StemSource" AS source,
    CASE
        WHEN s."status" = 'READY' THEN 'READY'::"VariantStatus"
        WHEN s."status" = 'FAILED' THEN 'FAILED'::"VariantStatus"
        WHEN s."status" = 'ANALYZING' THEN 'ANALYZING'::"VariantStatus"
        WHEN s."status" = 'SPLITTING' THEN 'SPLITTING'::"VariantStatus"
        ELSE 'QUEUED'::"VariantStatus"
    END AS status,
    'stems/' || s."id" AS "stemsPrefix",  -- legacy songs have stems at the bare prefix; resolved at read time
    pd."storageKey" AS "pitchKey",
    pd."frameCount" AS "frameCount",
    pd."hopDuration" AS "hopDuration",
    s."externalJobId",
    s."errorMessage",
    s."createdAt",
    s."updatedAt"
FROM "Song" s
LEFT JOIN "PitchData" pd ON pd."songId" = s."id";

-- Mark each backfilled variant as the active one for its song.
UPDATE "Song" s
SET "activeVariantId" = sv."id"
FROM "SongVariant" sv
WHERE sv."songId" = s."id" AND sv."source" = 'STUDIO';
