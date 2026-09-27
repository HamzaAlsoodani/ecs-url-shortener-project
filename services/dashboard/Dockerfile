
FROM golang:1.23 AS builder
WORKDIR /app


COPY go.mod ./
RUN go mod download

COPY . .


RUN go mod tidy && CGO_ENABLED=0 go build -o dashboard .

FROM debian:bookworm-slim AS runtime
WORKDIR /app

RUN groupadd --system appgroup \
    && useradd --system --gid appgroup --create-home appuser

# Only the program file, nothing else
COPY --from=builder --chown=appuser:appgroup /app/dashboard /app/dashboard

USER appuser
EXPOSE 8081

CMD ["/app/dashboard"]
