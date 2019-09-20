FROM alpine:3.10 as build

# persistent / runtime deps
RUN set -eux; \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    echo "@testing http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories; \
    cat /etc/apk/repositories; \
	apk update; \
	apk add --no-cache \
		apr-dev \
        apr-util-dev \
        aspell-dev \
        autoconf \
        bison \
        bzip2-dev \
        bzip2-static@testing \
        curl-dev \
        curl-static \
        db-dev \
        enchant-dev \
        expat-dev \
        freetds-dev \
        freetype-dev \
        freetype-static \
        g++ \
        gdbm-dev \
        gmp-dev \
        icu-dev \
        icu-static \
        libevent-dev \
        libevent-static \
        libgcrypt-dev \
        libgd \
        libjpeg-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libpng-static \
        libssh2-dev \
        libtool \
        libxml2-dev \
        libxslt-dev \
        libzip-dev \
        make \
        mariadb-dev \
        net-snmp-dev \
        nghttp2-dev \
        nghttp2-static \
        openldap-dev \
        openssl-dev \
        openssl-libs-static@testing \
        readline-dev \
        sqlite-dev \
        sqlite-static \
        unixodbc-dev \
        zlib-dev \
        zlib-static@testing \
	;

RUN set -eux; \
    apk add --no-cache \
        readline \
        readline-dev \
        libedit \
        libedit-dev \
        libsodium-dev \
        argon2-dev \
    ;

# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# Adds GNU HASH segments to generated executables (this is used if present, and is much faster than sysv hash; in this configuration, sysv hash is also generated)
# https://github.com/docker-library/php/issues/272
#ENV PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2"
#ENV PHP_CPPFLAGS="$PHP_CFLAGS"
#ENV PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie"


ENV PHP_INI_DIR .
ENV PHP_VERSION 7.2.22

WORKDIR /opt
COPY src /opt/src

RUN set -eux; \
# src
    cd /opt/src && ls -l; \
    mkdir -p /opt/src/php; \
    tar zxf php-src-php-7.2.22.tar.gz -C /opt/src/php --strip-components=1; \
# php ext
    mkdir -p /opt/src/php/ext/redis /opt/src/php/ext/swoole; \
    tar zxf phpredis-5.0.2.tar.gz -C /opt/src/php/ext/redis --strip-components=1; \
    tar zxf swoole-src-4.4.6.tar.gz -C /opt/src/php/ext/swoole --strip-components=1; \
# 映射
    ln -s /usr/include/libxml2/libxml/ /usr/include/libxml; \
# php
    mkdir -p /opt/bin; \
    mkdir -p /opt/bin/conf.d; \
    cd /opt/src/php; \
    ./buildconf --force; \
    ./configure --help | grep swoole; \
    (./configure \
        PHP_LDFLAGS=-all-static LIBS="$(pkg-config --libs --static libcurl)" \
#        --build="$gnuArch" \
        --prefix='/opt/bin' \
        --exec-prefix=/opt/bin \
#        --with-libdir="lib/$debMultiarch" \
        --with-config-file-path="$PHP_INI_DIR" \
        --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
        --enable-static \
        --enable-cli --disable-cgi \
        --disable-all \
        --enable-phpdbg \
# make sure invalid --configure-flags are fatal errors intead of just warnings
		--enable-option-checking=fatal \
# https://github.com/docker-library/php/issues/439
        --with-mhash \
# --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
        --enable-ftp \
# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
        --enable-mbstring=all \
# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
        --enable-mysqlnd \
# https://wiki.php.net/rfc/argon2_password_hash (7.2+)
        --with-password-argon2 \
# https://wiki.php.net/rfc/libsodium
        --with-sodium \
        \
        --enable-inline-optimization \
        --disable-rpath \
        --with-pic \
        --enable-calendar \
          --with-cdb \
        --enable-ctype \
          --with-curl \
        --enable-dom \
        --enable-exif \
        --with-gd \
          --with-freetype-dir \
          --disable-gd-jis-conv \
          --with-jpeg-dir \
          --with-png-dir \
        --with-gdbm \
        --with-iconv \
        --with-icu-dir=/usr \
        --enable-json \
        --enable-mysqlnd \
          --with-mysqli=mysqlnd \
          --with-pdo-mysql=mysqlnd \
          --with-openssl \
          --with-pcre-regex \
        --enable-pcntl \
        --enable-pdo \
          --with-pdo-mysql=mysqlnd \
          --with-pdo-sqlite \
        --enable-phar \
        --enable-posix \
        --enable-session \
        --enable-shmop \
        --enable-soap \
        --enable-sockets \
          --with-sqlite3 \
        --enable-sysvmsg \
        --enable-sysvsem \
        --enable-sysvshm \
        --enable-xml \
        --enable-xmlreader \
          --with-xmlrpc \
        --enable-wddx \
        --enable-zip \
          --with-zlib \
        --without-db1 \
        --without-db2 \
        --without-db3 \
        --without-qdbm \
        --with-pdo-dblib \
        --enable-opcache \
        \
        --with-curl \
        --with-readline \
        --with-libedit \
        --with-openssl \
        --with-zlib \
        --enable-libxml \
# 第三方扩展
#        --enable-swoole \
#        --enable-redis \
        \
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