
FROM golang:1.24 AS builder
WORKDIR /app


COPY go.mod go.sum ./
RUN go mod download

COPY . .


RUN CGO_ENABLED=0 go build -o worker .

FROM debian:bookworm-slim AS runtime
WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system appgroup \
    && useradd --system --gid appgroup --create-home appuser

# Only the program file, nothing else
COPY --from=builder --chown=appuser:appgroup /app/worker /app/worker

USER appuser


CMD ["/app/worker"]
