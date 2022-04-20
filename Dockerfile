FROM alpine as build
RUN \
        apk -U add alpine-sdk doas && \
        adduser -D -G abuild abuild && \
        mkdir -p /var/cache/distfiles && \
        chmod g+w /var/cache/distfiles
USER abuild
RUN \
	cd /tmp && \
        abuild-keygen -a -n && \
        git clone https://gitlab.alpinelinux.org/alpine/aports && \
        cd aports/main/unbound && \
        abuild -r

FROM alpine
COPY --from=build /home/abuild/packages/main/x86_64/ /tmp/pkgs
RUN \
	apk --no-cache --allow-untrusted add /tmp/pkgs/unbound-libs*.apk /tmp/pkgs/unbound*.apk && \
	rm -rf /var/cache/apk/* /tmp/pkgs
EXPOSE 53 53/udp
ENTRYPOINT ["/usr/sbin/unbound", "-d"]
