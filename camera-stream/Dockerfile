FROM alpine:3.20

RUN apk add --no-cache ffmpeg bash

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 8081

CMD ["/usr/local/bin/start.sh"]
