import re

from prometheus_client import Counter, Gauge, Histogram

HTTP_REQUESTS_TOTAL = Counter(
    "quiz_http_requests_total",
    "HTTP requests processed by the Quiz API.",
    ["method", "route", "status_code", "environment"],
)

HTTP_REQUEST_DURATION_SECONDS = Histogram(
    "quiz_http_request_duration_seconds",
    "Quiz API request latency in seconds.",
    ["method", "route", "environment"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10),
)

HTTP_REQUESTS_IN_PROGRESS = Gauge(
    "quiz_http_requests_in_progress",
    "Quiz API requests currently being processed.",
    ["environment"],
)

QUIZ_SUBMISSIONS_TOTAL = Counter(
    "quiz_quiz_submissions_total",
    "Quiz submissions processed by the API.",
    ["environment", "outcome"],
)

QUIZ_SCORE_PERCENT = Histogram(
    "quiz_quiz_score_percent",
    "Distribution of completed quiz scores as a percentage.",
    ["environment"],
    buckets=(10, 25, 50, 75, 90, 100),
)


def route_label(request) -> str:
    route = request.scope.get("route")
    template = getattr(route, "path", None)
    if template:
        return template
    return re.sub(r"/\d+(?=/|$)", "/{id}", request.url.path)
