FROM alpine:3.20
# hadolint ignore=DL3018
RUN apk add --no-cache bash git inotify-tools openssh && \
    mkdir -p /app

WORKDIR /app

COPY gitwatch.sh entrypoint.sh ./

RUN chmod +x /app/gitwatch.sh /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
