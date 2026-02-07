FROM alpine:latest
RUN apk --no-cache add ca-certificates
ARG ARTIFACT=https://rnd-public.sfo3.digitaloceanspaces.com/taiidani/no-time-to-explain/latest.tgz
ADD --unpack ${ARTIFACT} /app/
CMD ["/app/no-time-to-explain"]
