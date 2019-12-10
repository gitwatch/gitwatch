FROM alpine:3.1
RUN apk add --update bash git inotify-tools openssh && rm -rf /var/cache/apk/*

RUN mkdir -p /app
WORKDIR /app
ADD gitwatch.sh ./ 

RUN chmod 755 *.sh

ENTRYPOINT ["./gitwatch.sh"]
