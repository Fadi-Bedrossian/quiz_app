import logging
import time
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Response
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .config import get_settings
from .db import Base, SessionLocal, engine, get_db
from .logging_config import setup_logging
from .metrics import (
    HTTP_REQUEST_DURATION_SECONDS,
    HTTP_REQUESTS_IN_PROGRESS,
    HTTP_REQUESTS_TOTAL,
    QUIZ_SCORE_PERCENT,
    QUIZ_SUBMISSIONS_TOTAL,
    route_label,
)
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
async def request_logging_and_metrics(request, call_next):
    if request.url.path == "/metrics":
        return await call_next(request)

    started = time.perf_counter()
    status_code = 500
    HTTP_REQUESTS_IN_PROGRESS.labels(environment=settings.app_environment).inc()
    try:
        response = await call_next(request)
        status_code = response.status_code
        return response
    finally:
        duration_seconds = time.perf_counter() - started
        route = route_label(request)
        HTTP_REQUESTS_TOTAL.labels(
            method=request.method,
            route=route,
            status_code=str(status_code),
            environment=settings.app_environment,
        ).inc()
        HTTP_REQUEST_DURATION_SECONDS.labels(
            method=request.method,
            route=route,
            environment=settings.app_environment,
        ).observe(duration_seconds)
        HTTP_REQUESTS_IN_PROGRESS.labels(environment=settings.app_environment).dec()
        logger.info(
            "http_request",
            extra={
                "method": request.method,
                "path": route,
                "status_code": status_code,
                "duration_ms": round(duration_seconds * 1000, 2),
            },
        )


@app.get("/api/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/metrics", include_in_schema=False)
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


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
            QUIZ_SUBMISSIONS_TOTAL.labels(
                environment=settings.app_environment,
                outcome="invalid",
            ).inc()
            raise HTTPException(status_code=400, detail=f"Unknown question {answer.question_id}")
        ok = answer.selected_index == question.correct_index
        score += int(ok)
        results.append(
            ResultItem(
                question_id=question.id,
                selected_index=answer.selected_index,
                correct_index=question.correct_index,
                correct=ok,
                explanation=question.explanation,
            )
        )
    total = len(results)
    percentage = round((score / total * 100) if total else 0, 1)
    QUIZ_SUBMISSIONS_TOTAL.labels(
        environment=settings.app_environment,
        outcome="completed",
    ).inc()
    QUIZ_SCORE_PERCENT.labels(environment=settings.app_environment).observe(percentage)
    return SubmitResponse(
        score=score,
        total=total,
        percentage=percentage,
        results=results,
    )


@app.get("/api/admin/questions", response_model=list[QuestionAdmin])
def admin_list(db: Session = Depends(get_db)):
    return db.scalars(select(Question).order_by(Question.id)).all()


@app.post("/api/admin/questions", response_model=QuestionAdmin, status_code=201)
def admin_create(
    payload: QuestionCreate,
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
    db: Session = Depends(get_db),
):
    row = db.get(Question, question_id)
    if not row:
        raise HTTPException(status_code=404, detail="Question not found")
    db.delete(row)
    db.commit()
