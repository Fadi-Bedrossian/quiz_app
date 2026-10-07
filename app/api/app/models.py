from sqlalchemy import JSON, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class Question(Base):
    __tablename__ = "questions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    prompt: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    options: Mapped[list[str]] = mapped_column(JSON, nullable=False)
    correct_index: Mapped[int] = mapped_column(Integer, nullable=False)
    explanation: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[str] = mapped_column(String(80), default="science")
    difficulty: Mapped[str] = mapped_column(String(30), default="easy")
