"""Environment configuration validated at startup via pydantic-settings."""

from pydantic_settings import BaseSettings


class WorkerConfig(BaseSettings):
    """Pitch worker configuration from environment variables.

    Fails fast on missing required values at startup.
    """

    # Required — no defaults
    redis_url: str
    database_url: str
    r2_account_id: str
    r2_access_key_id: str
    r2_secret_access_key: str
    r2_bucket_name: str

    # Pitch estimator selection: "pyin" (legacy) or "pesto" (Step 3 of roadmap).
    pitch_estimator: str = "pesto"

    # pYIN extraction parameters (used when pitch_estimator="pyin")
    pyin_fmin: float = 65.0
    pyin_fmax: float = 1100.0
    pyin_hop_length: int = 512
    pyin_sample_rate: int = 44100
    # Minimum voiced probability from pYIN to accept a frame as voiced.
    # Step 2 of the pitch quality roadmap — filters out the low-confidence
    # frames that were silently accepted by the default (0.5) and caused
    # instrument-bleed garbage pitches in dense sections.
    pyin_voiced_prob_thresh: float = 0.8

    # PESTO extraction parameters (used when pitch_estimator="pesto")
    pesto_step_size_ms: float = 11.6  # ~512 hop at 44100 Hz, matches pYIN output density
    pesto_sample_rate: int = 44100
    pesto_confidence_thresh: float = 0.5

    # RMVPE reconciliation (step 4 of the pitch quality roadmap).
    # RMVPE runs on the FULL mix as a second opinion; its per-frame output
    # is reconciled against pYIN by src/reconcile.py.
    rmvpe_voiced_thresh: float = 0.5
    # Pitch disagreement threshold in semitones. Above this, reconcile picks
    # the higher-confidence tracker instead of blending. 50 cents = 0.5 semitones.
    reconcile_agreement_semitones: float = 0.5
    # Phase C dark-launch toggle: when True, the worker downloads the full mix,
    # runs RMVPE as a second opinion, and feeds reconcile_tracks to produce the
    # final frames. Default False — behavior must be byte-identical to pre-Phase-C
    # when this flag is off.
    enable_rmvpe_reconcile: bool = False
    rmvpe_model_dir: str = "/app/models"

    # Validation thresholds
    max_unvoiced_ratio: float = 0.9

    # Sentry (empty = disabled)
    sentry_dsn: str = ""

    # Worker behavior
    heartbeat_interval_seconds: int = 60
    queue_name: str = "pitch-analysis"
    lock_duration_ms: int = 600_000  # 10 min — large stems can take ~7 min

    model_config = {"env_prefix": "", "case_sensitive": False}
