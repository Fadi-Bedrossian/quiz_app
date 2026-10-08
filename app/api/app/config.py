from functools import lru_cache
from pathlib import Path
from typing import Any
from urllib.parse import quote_plus

from pydantic_settings import BaseSettings, SettingsConfigDict


def _read_secret_file(path: str) -> str:
    secret_path = Path(path)
    if not secret_path.is_file():
        return ""
    return secret_path.read_text(encoding="utf-8").strip()


class Settings(BaseSettings):
    app_name: str = "quiz-api"
    app_environment: str = "local"
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "quiz"
    db_user: str = "quizadmin"
    db_password: str = ""
    db_password_file: str = "/mnt/secrets-store/postgres-admin-password"
    db_sslmode: str = "require"
    database_url_override: str = ""
    appinsights_connection_string: str = ""
    appinsights_connection_string_file: str = "/mnt/secrets-store/appinsights-connection-string"
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    def model_post_init(self, context: Any, /) -> None:
        if not self.db_password:
            self.db_password = _read_secret_file(self.db_password_file)
        if not self.appinsights_connection_string:
            self.appinsights_connection_string = _read_secret_file(
                self.appinsights_connection_string_file
            )

    @property
    def database_url(self) -> str:
        if self.database_url_override:
            return self.database_url_override
        user = quote_plus(self.db_user)
        password = quote_plus(self.db_password)
        return (
            f"postgresql+psycopg://{user}:{password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}?sslmode={self.db_sslmode}"
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
