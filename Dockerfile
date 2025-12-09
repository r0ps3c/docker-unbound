FROM alpine

RUN \
	apk --no-cache add unbound bind-tools && \
	rm -rf /var/cache/apk/* && \
	# Unbound package creates unbound user/group automatically
	# Create runtime directories and set ownership
	mkdir -p /var/run/unbound && \
	chown -R unbound:unbound /etc/unbound /var/run/unbound

USER unbound
EXPOSE 53 53/udp

# Health check: verify Unbound is responding
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
	CMD nslookup -type=NS . 127.0.0.1 > /dev/null || exit 1

ENTRYPOINT ["/usr/sbin/unbound", "-d"]
