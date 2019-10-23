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

# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# Adds GNU HASH segments to generated executables (this is used if present, and is much faster than sysv hash; in this configuration, sysv hash is also generated)
# https://github.com/docker-library/php/issues/272
ENV PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2"
ENV PHP_CPPFLAGS="$PHP_CFLAGS"
ENV PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie"

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
# 190914
        libsodium-dev \
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
    ; \
    rm -rf /var/lib/apt/lists/*;
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
# 编译依赖静态库
#    cd /opt/src; \
#    mkdir -p /opt/src/krd5; \
#    tar zxf krb5-krb5-1.16.3-final.tar.gz -C /opt/src/krd5 --strip-components=1; \
#    cd /opt/src/krd5/src; \
#    autoreconf; \
#    ./configure \
#        --enable-static \
#        --disable-shared \
#        --enable-maintainer-mode \
#        --enable-dns-for-realm \
#        ; \
#    make -j "$(nproc)"; \
#    make install; \
# src
    cd /opt/src && ls -l; \
    mkdir -p /opt/src/php; \
    tar zxf php-src-php-7.2.22.tar.gz -C /opt/src/php --strip-components=1; \
# php ext
    mkdir -p /opt/src/php/ext/redis /opt/src/php/ext/swoole; \
    tar zxf phpredis-5.0.2.tar.gz -C /opt/src/php/ext/redis --strip-components=1; \
    tar zxf swoole-src-4.4.6.tar.gz -C /opt/src/php/ext/swoole --strip-components=1; \
# 映射
#    ld -static -lgssapi_krb5; \
#    ld -static -lkrb5; \
#    ld -static -lk5crypto; \
#    ld -static -lkrb5support; \
# php
    mkdir -p /opt/bin; \
    mkdir -p /opt/bin/conf.d; \
    cd /opt/src/php; \
    ./buildconf --force; \
    ./configure --help | grep swoole; \
    export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/:/usr/local/lib/:/usr/local/lib/krb5; \
    (./configure \
        LIBS="$( \
            pkg-config --libs --static \
                 \
                libsodium libargon2 libcrypto++ \
        )" \
#        PHP_LDFLAGS=-all-static \
        CFLAGS="-static $PHP_CFLAGS" \
        LDFLAGS="-static $PHP_LDFLAGS" \
        CPPFLAGS="$PHP_CPPFLAGS" \
#        CFLAGS="-static $PHP_CFLAGS" \
#        LDFLAGS="-static $PHP_LDFLAGS" \
        --build="$gnuArch" \
        --prefix='/opt/bin' \
        --exec-prefix=/opt/bin \
        --with-libdir="lib/$debMultiarch" \
        --with-config-file-path="$PHP_INI_DIR" \
        --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
        --enable-static \
        --enable-cli --disable-cgi \
        --disable-all \
# make sure invalid --configure-flags are fatal errors intead of just warnings
		--enable-option-checking=fatal \
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
#        --with-curl \
        --with-readline \
        --with-libedit \
        --with-openssl \
        --with-zlib \
# bundled pcre does not support JIT on s390x
# https://manpages.debian.org/stretch/libpcre3-dev/pcrejit.3.en.html#AVAILABILITY_OF_JIT_SUPPORT
        $(test "$gnuArch" = 's390x-linux-gnu' && echo '--without-pcre-jit') \
# 第三方扩展
        --enable-swoole \
        --enable-redis \
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