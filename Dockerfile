FROM alpine:3.1
# hadolint ignore=DL3018
RUN apk add --no-cache bash git inotify-tools openssh

RUN mkdir -p /app
WORKDIR /app
COPY gitwatch.sh ./ 

RUN chmod 755 -- *.sh

ENTRYPOINT ["./gitwatch.sh"]
