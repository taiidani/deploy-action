FROM scratch
ARG NAME
COPY artifacts/${NAME} /app/
CMD ["/app/${NAME}"]
