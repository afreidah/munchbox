FROM golang:1.25-alpine AS builder

WORKDIR /build

COPY go.mod go.sum ./
RUN go mod download

COPY *.go ./
COPY templates/ templates/
COPY static/ static/

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o trivy-dashboard .

FROM alpine:3.21

RUN apk add --no-cache ca-certificates

COPY --from=builder /build/trivy-dashboard /usr/local/bin/

EXPOSE 8080

ENTRYPOINT ["trivy-dashboard"]
