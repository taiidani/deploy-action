FROM alpine:latest
RUN apk --no-cache add ca-certificates
ADD --unpack https://rnd-public.sfo3.digitaloceanspaces.com/taiidani/no-time-to-explain/no-time-to-explain-2026.01.08-905e74_linux_amd64.tgz /app/
CMD ["/app/no-time-to-explain"]
