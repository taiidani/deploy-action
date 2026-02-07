FROM alpine:latest
RUN apk --no-cache add ca-certificates
ARG ARTIFACT
ADD --unpack ${ARTIFACT} /app/
CMD ["/app/no-time-to-explain"]
