FROM golang:1.25-alpine AS builder

WORKDIR /build

COPY go.mod ./
RUN go mod download

COPY *.go ./
COPY templates/ templates/
COPY static/ static/

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o phlebotomy-game .

FROM alpine:3.21

RUN apk add --no-cache ca-certificates

COPY --from=builder /build/phlebotomy-game /usr/local/bin/

EXPOSE 8080

ENTRYPOINT ["phlebotomy-game"]
