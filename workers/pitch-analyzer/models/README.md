# Vendored Model Weights

Model checkpoints are downloaded into this directory at Docker build time.
They are **not** committed to git (see `.gitignore` — `models/*.pt`).

## rmvpe.pt — RMVPE pitch estimator

Used by `src/rmvpe.py` for the second-opinion pitch track that runs against the
original mix. See `docs/yin-comparison-results.md` step 4.

| Field                       | Value                                                                                                 |
| --------------------------- | ----------------------------------------------------------------------------------------------------- |
| Source                      | https://huggingface.co/lj1995/VoiceConversionWebUI/blob/main/rmvpe.pt                                 |
| Repository declared license | MIT (see https://huggingface.co/lj1995/VoiceConversionWebUI)                                          |
| Upstream paper              | RMVPE — Robust Model for Vocal Pitch Estimation in Polyphonic Music, https://arxiv.org/abs/2306.15412 |
| Upstream code               | https://github.com/Dream-High/RMVPE                                                                   |
| File size                   | 181 MB                                                                                                |
| SHA256                      | `6d62215f4306e3ca278246188607209f09af3dc77ed4232efdd069798c4ec193`                                    |
| Format                      | PyTorch pickle (`torch.HalfStorage`, `_rebuild_tensor_v2`, `OrderedDict`)                             |

The Dockerfile uses `curl` + `sha256sum` to fetch and verify the file at build
time. If the SHA changes, the build fails — that's intentional. Update this
table and the Dockerfile together if upstream is republished.

### Why vendor from `lj1995/VoiceConversionWebUI` and not `Dream-High/RMVPE`

Upstream Dream-High/RMVPE has unclear licensing on the weights themselves. The
RVC ecosystem mirror at `lj1995/VoiceConversionWebUI` declares MIT on the HF
repo metadata, has been the de facto distribution point for RMVPE weights since
2023, and is what every RVC fork pins to. We rely on the HF repo's MIT
declaration; if that ever gets retracted, we revisit.

### Local development

Either let `docker build` fetch it (slow first build, cached after) or run:

```bash
curl -L -o workers/pitch-analyzer/models/rmvpe.pt \
  https://huggingface.co/lj1995/VoiceConversionWebUI/resolve/main/rmvpe.pt
echo "6d62215f4306e3ca278246188607209f09af3dc77ed4232efdd069798c4ec193  workers/pitch-analyzer/models/rmvpe.pt" | sha256sum -c
```
