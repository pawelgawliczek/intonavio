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

    # pYIN extraction parameters
    pyin_fmin: float = 65.0
    pyin_fmax: float = 1100.0
    pyin_hop_length: int = 512
    pyin_sample_rate: int = 44100

    # Validation thresholds
    max_unvoiced_ratio: float = 0.9

    # Sentry (empty = disabled)
    sentry_dsn: str = ""

    # Worker behavior
    heartbeat_interval_seconds: int = 60
    queue_name: str = "pitch-analysis"
    lock_duration_ms: int = 600_000  # 10 min — large stems can take ~7 min

    model_config = {"env_prefix": "", "case_sensitive": False}
