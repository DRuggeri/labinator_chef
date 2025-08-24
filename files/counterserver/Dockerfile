FROM golang:1.25-alpine AS builder

WORKDIR /app

COPY go.mod .

RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o counterserver .


FROM scratch
COPY --from=builder /app/counterserver /counterserver

EXPOSE 8080

CMD ["/counterserver"]