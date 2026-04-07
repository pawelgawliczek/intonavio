"""Environment configuration validated at startup via pydantic-settings."""

from pydantic_settings import BaseSettings


class WorkerConfig(BaseSettings):
    """Stem-splitter worker configuration from environment variables.

    Fails fast on missing required values at startup.
    """

    # Required — no defaults
    redis_url: str
    database_url: str
    r2_account_id: str
    r2_access_key_id: str
    r2_secret_access_key: str
    r2_bucket_name: str

    # BS-Roformer model (baked into image at /app/models)
    model_file: str = "model_bs_roformer_ep_317_sdr_12.9755.ckpt"
    model_dir: str = "/app/models"

    # Sentry (empty = disabled)
    sentry_dsn: str = ""

    # Worker behavior
    heartbeat_interval_seconds: int = 60
    queue_name: str = "stem-split-local"
    # BS-Roformer on CPU takes ~25-40 min for a 4-min track; give jobs 90 min.
    lock_duration_ms: int = 5_400_000

    # Lazy-load / idle-unload. After this many seconds of no job activity,
    # the loaded BS-Roformer model is dropped from memory (~3-4 GB → ~200 MB).
    # Next job pays ~5s reload cost, negligible vs. 25-40 min job runtime.
    idle_unload_seconds: int = 600  # 10 min

    model_config = {"env_prefix": "", "case_sensitive": False, "protected_namespaces": ()}
