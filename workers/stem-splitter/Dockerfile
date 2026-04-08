FROM python:3.11-slim AS base

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      libsndfile1 \
      ffmpeg \
      curl \
      unzip \
      ca-certificates \
      build-essential \
      python3-dev && \
    rm -rf /var/lib/apt/lists/*

# Deno is required by yt-dlp 2026+ to solve YouTube's signature/n-challenge JS.
RUN curl -fsSL https://deno.land/install.sh | sh -s -- -y --no-modify-path && \
    mv /root/.deno/bin/deno /usr/local/bin/deno && \
    deno --version

WORKDIR /app

# numpy must be present before diffq's setup.py runs (it imports numpy at build time).
COPY requirements.txt .
RUN pip install --no-cache-dir "numpy<2" "cython<4" && \
    pip install --no-cache-dir -r requirements.txt && \
    apt-get purge -y build-essential python3-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Vendored BS-Roformer Viperx 1297 weights + config — see models/README.md for
# license and provenance. Download-at-build with SHA256 verification; build fails
# on mismatch.
ARG BSROFORMER_CKPT_SHA256=5b84f37e8d444c8cb30c79d77f613a41c05868ff9c9ac6c7049c00aefae115aa
ARG BSROFORMER_YAML_SHA256=2bfdd16c656bd9519aba757cc4f8834b7ede675eb1e00ec4772d74ae1c41af7f
RUN mkdir -p /app/models && \
    curl -fL -o /app/models/model_bs_roformer_ep_317_sdr_12.9755.ckpt \
      https://github.com/TRvlvr/model_repo/releases/download/all_public_uvr_models/model_bs_roformer_ep_317_sdr_12.9755.ckpt && \
    curl -fL -o /app/models/model_bs_roformer_ep_317_sdr_12.9755.yaml \
      https://github.com/nomadkaraoke/python-audio-separator/releases/download/model-configs/model_bs_roformer_ep_317_sdr_12.9755.yaml && \
    cd /app/models && \
    echo "${BSROFORMER_CKPT_SHA256}  model_bs_roformer_ep_317_sdr_12.9755.ckpt" | sha256sum -c - && \
    echo "${BSROFORMER_YAML_SHA256}  model_bs_roformer_ep_317_sdr_12.9755.yaml" | sha256sum -c -

COPY models/README.md ./models/README.md
COPY src/ ./src/

CMD ["python", "-m", "src.worker"]
