# Original credit:

FROM alpine:latest

LABEL maintainer="YuXiao(xiao.950901@gmail.com)"

RUN \
  echo 'http://dl-cdn.alpinelinux.org/alpine/edge/testing/' >> /etc/apk/repositories && \
  sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
  apk update && apk upgrade && \
  apk add -u bash gettext vim openldap openldap-clients openldap-back-mdb openldap-passwd-pbkdf2 openldap-overlay-ppolicy openldap-overlay-memberof openldap-overlay-refint && \
  mkdir -p /run/openldap /data && \
  rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/*

EXPOSE 389 636

COPY bin/entrypoint.sh /
COPY configuration /etc/openldap/

VOLUME ["/data"]

STOPSIGNAL SIGTERM

CMD ["/entrypoint.sh"]
