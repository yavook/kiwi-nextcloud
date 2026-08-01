ARG NC_VERSION=stable
FROM nextcloud:${NC_VERSION}
LABEL maintainer="jmm@yavook.de"

#########
# add s6 overlay
# https://github.com/just-containers/s6-overlay
#########

ARG S6_OVERLAY_VERSION=3.2.3.2
ENV PATH=/command:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN set -ex; \
    \
    curl \
      --proto '=https' --tlsv1.2 -sSLf \
      "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
      | tar -JxpC /; \
    curl \
      --proto '=https' --tlsv1.2 -sSLf \
      "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz" \
      | tar -JxpC /; \
    \
    mkdir -p /etc/s6-overlay/config; \
    echo "${PATH}" > /etc/s6-overlay/config/global_path;

ENTRYPOINT [ "/init" ]

# with-contenv + original container ENTRYPOINT + original container CMD
CMD [ "/command/with-contenv", "/entrypoint.sh", "php-fpm" ]

#########
# configure php-fpm
#########

COPY zzz-kiwi.conf /usr/local/etc/php-fpm.d/zzz-kiwi.conf

#########
# add nginx
#########

COPY nginx /opt/nginx

# add nginx.conf from examples: https://github.com/nextcloud/docker/tree/master/.examples
ADD \
  https://raw.githubusercontent.com/nextcloud/docker/master/.examples/docker-compose/insecure/mariadb/fpm/web/nginx.conf \
  /opt/nginx/nginx.conf

RUN set -ex; \
    \
    apk --no-cache add \
      nginx \
      patch \
    ; \
    \
    cd /opt/nginx; \
    # install nginx.conf
    patch -p1 < nginx.conf.patch; \
    rm -f nginx.conf.patch nginx.conf.orig; \
    mv nginx.conf /etc/nginx/nginx.conf; \
    \
    mkdir -p /etc/s6-overlay/s6-rc.d/run_nginx; \
    mv run_nginx.sh /etc/s6-overlay/s6-rc.d/run_nginx/run; \
    echo 'longrun' > /etc/s6-overlay/s6-rc.d/run_nginx/type; \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/run_nginx; \
    \
    apk --no-cache del patch; \
    cd /; rmdir /opt/nginx;
