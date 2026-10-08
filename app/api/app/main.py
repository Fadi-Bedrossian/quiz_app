import logging
import time
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import admin_claims
from .config import get_settings
from .db import Base, SessionLocal, engine, get_db
from .logging_config import setup_logging
from .models import Question
from .schemas import (
    QuestionAdmin,
    QuestionCreate,
    QuestionPublic,
    ResultItem,
    SubmitRequest,
    SubmitResponse,
)
from .seed import SEED_QUESTIONS

settings = get_settings()
setup_logging()
logger = logging.getLogger("quiz.api")


def init_db() -> None:
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        for item in SEED_QUESTIONS:
            exists = db.scalar(select(Question.id).where(Question.prompt == item["prompt"]))
            if exists:
                continue
            db.add(Question(**item))
            try:
                db.commit()
            except IntegrityError:
                db.rollback()


@asynccontextmanager
async def lifespan(_: FastAPI):
    if settings.appinsights_connection_string:
        try:
            from azure.monitor.opentelemetry import configure_azure_monitor
            configure_azure_monitor(connection_string=settings.appinsights_connection_string)
        except Exception:
            logger.exception("azure_monitor_configuration_failed")
    init_db()
    yield


app = FastAPI(title="Quiz API", version="1.0.0", lifespan=lifespan)


@app.middleware("http")
async def request_logging(request, call_next):
    started = time.perf_counter()
    response = await call_next(request)
    logger.info(
        "http_request",
        extra={
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "duration_ms": round((time.perf_counter() - started) * 1000, 2),
        },
    )
    return response


@app.get("/api/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/api/questions", response_model=list[QuestionPublic])
def questions(db: Session = Depends(get_db)):
    return db.scalars(select(Question).order_by(Question.id)).all()


@app.post("/api/quiz/submit", response_model=SubmitResponse)
def submit(payload: SubmitRequest, db: Session = Depends(get_db)):
    ids = [a.question_id for a in payload.answers]
    rows = db.scalars(select(Question).where(Question.id.in_(ids))).all()
    mapping = {q.id: q for q in rows}
    results = []
    score = 0
    for answer in payload.answers:
        question = mapping.get(answer.question_id)
        if not question:
            raise HTTPException(status_code=400, detail=f"Unknown question {answer.question_id}")
        ok = answer.selected_index == question.correct_index
        score += int(ok)
        results.append(ResultItem(
            question_id=question.id,
            selected_index=answer.selected_index,
            correct_index=question.correct_index,
            correct=ok,
            explanation=question.explanation,
        ))
    total = len(results)
    return SubmitResponse(
        score=score,
        total=total,
        percentage=round((score / total * 100) if total else 0, 1),
        results=results,
    )


@app.get("/api/admin/questions", response_model=list[QuestionAdmin])
def admin_list(
    _claims: dict = Depends(admin_claims),
    db: Session = Depends(get_db),
):
    return db.scalars(select(Question).order_by(Question.id)).all()


@app.post("/api/admin/questions", response_model=QuestionAdmin, status_code=201)
def admin_create(
    payload: QuestionCreate,
    _claims: dict = Depends(admin_claims),
    db: Session = Depends(get_db),
):
    row = Question(**payload.model_dump())
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@app.put("/api/admin/questions/{question_id}", response_model=QuestionAdmin)
def admin_update(
    question_id: int,
    payload: QuestionCreate,
    _claims: dict = Depends(admin_claims),
    db: Session = Depends(get_db),
):
    row = db.get(Question, question_id)
    if not row:
        raise HTTPException(status_code=404, detail="Question not found")
    for key, value in payload.model_dump().items():
        setattr(row, key, value)
    db.commit()
    db.refresh(row)
    return row


@app.delete("/api/admin/questions/{question_id}", status_code=204)
def admin_delete(
    question_id: int,
    _claims: dict = Depends(admin_claims),
    db: Session = Depends(get_db),
):
    row = db.get(Question, question_id)
    if not row:
        raise HTTPException(status_code=404, detail="Question not found")
    db.delete(row)
    db.commit()
