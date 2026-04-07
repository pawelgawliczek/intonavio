FROM python:3.11-slim AS base

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      libsndfile1 \
      ffmpeg \
      curl \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

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
