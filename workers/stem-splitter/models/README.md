# Vendored Model Weights

Model checkpoints and configs are downloaded into this directory at Docker build
time. They are **not** committed to git (see repo `.gitignore` —
`workers/stem-splitter/models/*.ckpt` and `*.yaml`).

## model_bs_roformer_ep_317_sdr_12.9755 — BS-Roformer Viperx 1297

The vocal/instrumental separation model used by `src/separator.py`. Replaces
the external StemSplit HTTP API. Rationale and benchmark results are in
`docs/yin-comparison-results.md` (step 5 — stem separation upgrade).

### Checkpoint file

| Field    | Value                                                                                                                  |
| -------- | ---------------------------------------------------------------------------------------------------------------------- |
| Filename | `model_bs_roformer_ep_317_sdr_12.9755.ckpt`                                                                            |
| Source   | https://github.com/TRvlvr/model_repo/releases/download/all_public_uvr_models/model_bs_roformer_ep_317_sdr_12.9755.ckpt |
| Size     | 639,331,213 bytes (~639 MB)                                                                                            |
| SHA256   | `5b84f37e8d444c8cb30c79d77f613a41c05868ff9c9ac6c7049c00aefae115aa`                                                     |
| Format   | PyTorch checkpoint (`torch.save` pickle)                                                                               |

### YAML config file

| Field    | Value                                                                                                                            |
| -------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Filename | `model_bs_roformer_ep_317_sdr_12.9755.yaml`                                                                                      |
| Source   | https://github.com/nomadkaraoke/python-audio-separator/releases/download/model-configs/model_bs_roformer_ep_317_sdr_12.9755.yaml |
| Size     | 2273 bytes                                                                                                                       |
| SHA256   | `2bfdd16c656bd9519aba757cc4f8834b7ede675eb1e00ec4772d74ae1c41af7f`                                                               |
| Format   | YAML — architecture + hyperparameters required by `audio-separator` to instantiate the model                                     |

Both files must be present side-by-side for `audio-separator` to load the model.

### Licensing

BS-Roformer weights and config are distributed by the UVR (Ultimate Vocal
Remover) community under the UVR project's permissive terms. The TRvlvr
`model_repo` release is the canonical public mirror referenced by every UVR
and audio-separator deployment. The YAML config is hosted by
`nomadkaraoke/python-audio-separator` because TRvlvr's release doesn't include
configs for this specific model. If either upstream is ever retracted, we
revisit — for now this is the de facto distribution pair.

### Local development

Either let `docker build` fetch both files (slow first build, cached after) or run:

```bash
curl -fL -o workers/stem-splitter/models/model_bs_roformer_ep_317_sdr_12.9755.ckpt \
  https://github.com/TRvlvr/model_repo/releases/download/all_public_uvr_models/model_bs_roformer_ep_317_sdr_12.9755.ckpt
curl -fL -o workers/stem-splitter/models/model_bs_roformer_ep_317_sdr_12.9755.yaml \
  https://github.com/nomadkaraoke/python-audio-separator/releases/download/model-configs/model_bs_roformer_ep_317_sdr_12.9755.yaml
cd workers/stem-splitter/models
echo "5b84f37e8d444c8cb30c79d77f613a41c05868ff9c9ac6c7049c00aefae115aa  model_bs_roformer_ep_317_sdr_12.9755.ckpt" | sha256sum -c
echo "2bfdd16c656bd9519aba757cc4f8834b7ede675eb1e00ec4772d74ae1c41af7f  model_bs_roformer_ep_317_sdr_12.9755.yaml" | sha256sum -c
```

The Dockerfile uses `curl` + `sha256sum` to fetch and verify both files at
build time. If either SHA changes, the build fails — that's intentional.
Update this table and the Dockerfile together if upstream is republished.
