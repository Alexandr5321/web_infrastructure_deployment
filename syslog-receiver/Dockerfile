FROM alpine:3.22

RUN apk add --no-cache socat

COPY receiver.sh /receiver.sh

RUN chmod +x /receiver.sh

CMD ["/receiver.sh"]
