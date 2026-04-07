FROM python:3.11-slim AS base

RUN apt-get update && \
    apt-get install -y --no-install-recommends libsndfile1 curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Vendored RMVPE weights — see models/README.md for license + provenance.
# Download-at-build with SHA256 verification; build fails on mismatch.
ARG RMVPE_SHA256=6d62215f4306e3ca278246188607209f09af3dc77ed4232efdd069798c4ec193
RUN mkdir -p /app/models && \
    curl -fL -o /app/models/rmvpe.pt \
      https://huggingface.co/lj1995/VoiceConversionWebUI/resolve/main/rmvpe.pt && \
    echo "${RMVPE_SHA256}  /app/models/rmvpe.pt" | sha256sum -c -

COPY models/README.md ./models/README.md
COPY src/ ./src/

CMD ["python", "-m", "src.worker"]
