FROM scratch
ARG ARTIFACT=https://rnd-public.sfo3.digitaloceanspaces.com/taiidani/guess-my-word/latest.tgz
ADD --unpack ${ARTIFACT} /app/
CMD ["/app/guess-my-word"]
