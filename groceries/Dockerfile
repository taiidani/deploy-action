FROM scratch
ARG ARTIFACT=https://rnd-public.sfo3.digitaloceanspaces.com/taiidani/groceries/latest.tgz
ADD --unpack ${ARTIFACT} /app/
CMD ["/app/groceries"]
