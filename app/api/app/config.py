from functools import lru_cache
from urllib.parse import quote_plus

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "quiz-api"
    auth_disabled: bool = False
    entra_tenant_id: str = ""
    entra_client_id: str = ""
    entra_audience: str = ""
    admin_group_id: str = ""
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "quiz"
    db_user: str = "quizadmin"
    db_password: str = ""
    db_sslmode: str = "require"
    database_url_override: str = ""
    appinsights_connection_string: str = ""
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

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
