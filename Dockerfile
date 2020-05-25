FROM alpine
RUN \
	apk --no-cache add unbound && \
	rm -rf /var/cache/apk/*
EXPOSE 53 53/udp
ENTRYPOINT ["/usr/sbin/unbound", "-d"]
