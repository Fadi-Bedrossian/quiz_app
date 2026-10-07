import os

os.environ["AUTH_DISABLED"] = "true"
os.environ["DATABASE_URL_OVERRIDE"] = "sqlite+pysqlite:///:memory:"
