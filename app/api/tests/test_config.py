from app.config import Settings


def test_settings_load_secrets_from_files(tmp_path):
    db_secret = tmp_path / "db-password"
    appinsights_secret = tmp_path / "appinsights"
    db_secret.write_text("db-from-file\n", encoding="utf-8")
    appinsights_secret.write_text("InstrumentationKey=test\n", encoding="utf-8")

    settings = Settings(
        db_password="",
        db_password_file=str(db_secret),
        appinsights_connection_string="",
        appinsights_connection_string_file=str(appinsights_secret),
        database_url_override="",
    )

    assert settings.db_password == "db-from-file"
    assert settings.appinsights_connection_string == "InstrumentationKey=test"


def test_explicit_secret_values_take_precedence_over_files(tmp_path):
    db_secret = tmp_path / "db-password"
    db_secret.write_text("db-from-file", encoding="utf-8")

    settings = Settings(
        db_password="db-explicit",
        db_password_file=str(db_secret),
        database_url_override="",
    )

    assert settings.db_password == "db-explicit"
