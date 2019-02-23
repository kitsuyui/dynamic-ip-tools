FROM gliderlabs/alpine:3.8@sha256:7e4b0c2dfeecc889242ec4a5c43dbd7cb2e8037e36dbc8c64a8d6a6461c078fb

ENV \
MYIP_VERSION='v0.3.4' \
MYIP_HASH='0c995b4e242740e7e9b71ee56b41e52e92362fcd9eac09159aa5ae69ef6526ba'

RUN \
apk --update add --no-cache \
  ca-certificates python3 jq curl && \
update-ca-certificates && \
pip3 install --no-cache-dir awscli && \
mkdir /lib64 && \
ln -s /lib/libc.musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2 && \
curl -fsSL "https://github.com/kitsuyui/myip/releases/download/${MYIP_VERSION}/myip_linux_amd64" > /usr/sbin/myip && \
echo "${MYIP_HASH}  /usr/sbin/myip" | sha256sum -s -c - && \
chmod +x /usr/sbin/myip

ADD main.sh /usr/bin/entrypoint
ENTRYPOINT entrypoint
