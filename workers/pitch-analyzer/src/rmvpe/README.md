# Vendored RMVPE

Inference-only vendoring of the RMVPE pitch tracker. No training code.

- Upstream: https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI
- Source file: `infer/lib/rmvpe.py`
  (raw: https://raw.githubusercontent.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI/main/infer/lib/rmvpe.py)
- SHA256 of fetched upstream file: `0a93a5dee4c127460de731499d436227fe81e5d23a100bccabd1bb2b4aa0df44`
- Upstream license: MIT

Modifications are listed in the header comment of `model.py`. Pretrained weights
(`models/rmvpe.pt`) are downloaded by the worker Dockerfile from
`lj1995/VoiceConversionWebUI` on Hugging Face and are not vendored here.
