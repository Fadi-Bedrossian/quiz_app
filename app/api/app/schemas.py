from pydantic import BaseModel, Field


class QuestionPublic(BaseModel):
    id: int
    prompt: str
    options: list[str]
    category: str
    difficulty: str
    model_config = {"from_attributes": True}


class Answer(BaseModel):
    question_id: int
    selected_index: int = Field(ge=0, le=3)


class SubmitRequest(BaseModel):
    answers: list[Answer]


class ResultItem(BaseModel):
    question_id: int
    selected_index: int
    correct_index: int
    correct: bool
    explanation: str


class SubmitResponse(BaseModel):
    score: int
    total: int
    percentage: float
    results: list[ResultItem]


class QuestionAdmin(BaseModel):
    id: int
    prompt: str
    options: list[str]
    correct_index: int
    explanation: str
    category: str
    difficulty: str
    model_config = {"from_attributes": True}


class QuestionCreate(BaseModel):
    prompt: str
    options: list[str] = Field(min_length=4, max_length=4)
    correct_index: int = Field(ge=0, le=3)
    explanation: str
    category: str = "science"
    difficulty: str = "easy"
