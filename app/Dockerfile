
FROM python:3.12-slim AS builder
WORKDIR /app

RUN python -m venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt


COPY . .



FROM python:3.12-slim AS runtime
WORKDIR /app


ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1


RUN groupadd --system appgroup \
    && useradd --system --gid appgroup --create-home appuser


COPY --from=builder --chown=appuser:appgroup /app /app

USER appuser
EXPOSE 8080

CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]
