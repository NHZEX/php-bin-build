FROM debian:buster-slim as build

# dependencies required for running "phpize"
# (see persistent deps below)
ENV PHPIZE_DEPS  autoconf dpkg-dev file g++ gcc libc-dev make pkg-config re2c bison

# persistent / runtime deps
RUN set -eux; \
    sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list; \
	apt update; \
	apt install -y --no-install-recommends \
		$PHPIZE_DEPS \
		ca-certificates \
		curl \
		xz-utils \
	; \
	apt clean;

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libargon2-dev \
        libcurl4-openssl-dev \
        libedit-dev \
        libsodium-dev \
        libsqlite3-dev \
        libssl-dev \
        libxml2-dev \
        zlib1g-dev \
# libedit required by readline
        libreadline-dev \
        ${PHP_EXTRA_BUILD_DEPS:-} \
    ; \
    apt clean;

ENV PHP_INI_DIR .
ENV PHP_VERSION 7.2.20

WORKDIR /opt
COPY src /opt/src

RUN set -eux; \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
    debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
# https://bugs.php.net/bug.php?id=74125
    if [ ! -d /usr/include/curl ]; then \
        ln -sT "/usr/include/$debMultiarch/curl" /usr/local/include/curl; \
    fi; \
# src
    cd /opt/src; \
    mkdir -p /opt/src/php /opt/src/redis /opt/src/swoole; \
    tar zxvf php-7.2.20.tar.gz -C /opt/src/php --strip-components=1; \
    tar zxvf phpredis-4.3.0.tar.gz -C /opt/src/redis --strip-components=1; \
    tar zxvf swoole-src-4.3.5.tar.gz -C /opt/src/swoole --strip-components=1; \
    mv /opt/src/redis /opt/src/php/ext/redis; \
    mv /opt/src/swoole /opt/src/php/ext/swoole; \
    ls -l /opt/src/php/ext; \
# php
    mkdir -p /opt/bin; \
    mkdir -p /opt/bin/conf.d; \
    cd /opt/src/php; \
    ./buildconf --force; \
    ./configure --help | grep swoole; \
    (./configure \
        CFLAGS=-static LDFLAGS=-static \
        --build="$gnuArch" \
        --prefix=/opt/bin \
        --exec-prefix=/opt/bin \
        --with-config-file-path="$PHP_INI_DIR" \
        --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
        --enable-static=yes \
        --enable-cli --disable-cgi \
        --disable-all \
# https://github.com/docker-library/php/issues/439
        --with-mhash \
# --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
        --enable-ftp \
# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
        --enable-mbstring \
# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
        --enable-mysqlnd \
# https://wiki.php.net/rfc/argon2_password_hash (7.2+)
        --with-password-argon2 \
# https://wiki.php.net/rfc/libsodium
        --with-sodium \
        \
        --enable-session \
#        --with-curl \
        --with-readline \
        --with-libedit \
        --with-openssl \
        --with-zlib \
        \
        --with-swoole --enable-swoole-static \
        --enable-redis \
# bundled pcre does not support JIT on s390x
# https://manpages.debian.org/stretch/libpcre3-dev/pcrejit.3.en.html#AVAILABILITY_OF_JIT_SUPPORT
        $(test "$gnuArch" = 's390x-linux-gnu' && echo '--without-pcre-jit') \
        --with-libdir="lib/$debMultiarch" \
        \
        ${PHP_EXTRA_CONFIGURE_ARGS:-} \
    ); \
    make -j "$(nproc)"; \
    make install;

FROM debian:buster-slim

COPY --from=build /opt/bin /opt/php
COPY ./docker-php-entrypoint /usr/local/bin/

WORKDIR /opt/php

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list; \
    ls -l bin; \
    ldd /opt/php/bin/php;

ENTRYPOINT ["bash"]
CMD ["/opt/php/bin/php", "-a"]