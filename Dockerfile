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
        libargon2-0-dev \
        libcurl4-openssl-dev \
        libedit-dev \
        libsodium-dev \
        libsqlite3-dev \
        libssl-dev \
        libxml2-dev \
        zlib1g-dev \
# libedit required by readline
        libreadline-dev \
# 190914
        libsodium-dev \
        libargon2-0-dev \
        libedit-dev \
        libcrypto++-dev \
        libnghttp2-dev \
        libidn2-0-dev \
        librtmp-dev \
        libpsl-dev \
        libgssapi-krb5-2 \
        libkrb5-dev \
        libk5crypto3 \
        libkrb5-3 \
        krb5-gss-samples \
        comerr-dev \
        libalberta2-dev \
        libldap2-dev \
        libssh2-1-dev \
        ${PHP_EXTRA_BUILD_DEPS:-} \
    ;
    # apt clean; # 加快运行速度

ENV PHP_INI_DIR .
ENV PHP_VERSION 7.2.22

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
    cd /opt/src && ls -l; \
    mkdir -p /opt/src/php; \
    tar zxf php-src-php-7.2.22.tar.gz -C /opt/src/php --strip-components=1; \
# php ext
    mkdir -p /opt/src/php/ext/redis /opt/src/php/ext/swoole; \
    tar zxf phpredis-4.3.0.tar.gz -C /opt/src/php/ext/redis --strip-components=1; \
    tar zxf swoole-src-4.4.5.tar.gz -C /opt/src/php/ext/swoole --strip-components=1; \
# 映射
# php
    mkdir -p /opt/bin; \
    mkdir -p /opt/bin/conf.d; \
    cd /opt/src/php; \
    ./buildconf --force; \
    ./configure --help | grep swoole; \
    (./configure \
        PHP_LDFLAGS=-all-static LIBS="$( \
            pkg-config --libs --static \
                libcurl \
        )" \
#        --with-libdir="lib/$debMultiarch" \
#        CFLAGS=-static LDFLAGS=-static \
        --build="$gnuArch" \
        --prefix='/' \
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
        --with-curl \
        --with-readline \
        --with-libedit \
        --with-openssl \
        --with-zlib \
# 第三方扩展
        --enable-swoole \
        --enable-redis \
# bundled pcre does not support JIT on s390x
# https://manpages.debian.org/stretch/libpcre3-dev/pcrejit.3.en.html#AVAILABILITY_OF_JIT_SUPPORT
        $(test "$gnuArch" = 's390x-linux-gnu' && echo '--without-pcre-jit') \
        \
        ${PHP_EXTRA_CONFIGURE_ARGS:-} \
    ) || (cat config.log && false); \
    make -j "$(nproc)" PHP_LDFLAGS=-all-static; \
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