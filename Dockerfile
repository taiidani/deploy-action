FROM alpine:latest
RUN apk --no-cache add ca-certificates
ARG NAME
COPY artifacts/${NAME} /app
CMD ["/app"]
