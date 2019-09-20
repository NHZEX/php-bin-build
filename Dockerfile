FROM centos:7 as build

# dependencies required for running "phpize"
# (see persistent deps below)
ENV PHPIZE_DEPS  autoconf dpkg-dev file g++ gcc libc-dev make pkg-config re2c bison

# persistent / runtime deps
RUN set -eux; \
    yum install -y epel-release; \
    ls -l /etc/yum.repos.d; \
    curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo; \
    curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo; \
    sed -i -e '/mirrors.cloud.aliyuncs.com/d' -e '/mirrors.aliyuncs.com/d' /etc/yum.repos.d/CentOS-Base.repo; \
	yum makecache; \
	yum repolist | grep epel; \
#	yum group install -y "Development Tools"; \
    yum -y install centos-release-scl; \
	yum -y install autoconf dpkg-dev file gcc-c++ gcc glibc-devel make re2c bison; \
    yum -y install devtoolset-7-gcc devtoolset-7-gcc-c++ devtoolset-7-binutils; \
    yum -y install glibc-static; \
    echo "source /opt/rh/devtoolset-7/enable" >>/etc/profile; \
	yum clean all;

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
    yum install -y \
        libxml2-devel \
        openssl \
        openssl-devel \
        curl-devel \
        libjpeg-devel \
        libpng-devel \
        freetype-devel \
        libmcrypt-devel \
        mhash \
        gd \
        gd-devel \
        bzip2-devel \
        gmp-devel \
        readline-devel libedit libedit-devel \
        libsodium libsodium-devel \
        libargon2-devel \
        \
        zlib-static \
        openssl-static \
        libcurl-devel \
        ; \
    yum clean all;

ENV PHP_INI_DIR .
ENV PHP_VERSION 7.2.22

WORKDIR /opt
COPY src /opt/src

RUN set -eux; \
# test
    gcc --print-file-name=libc.a; \
# src
    cd /opt/src && ls -l; \
    mkdir -p /opt/src/php; \
    tar zxf php-src-php-7.2.22.tar.gz -C /opt/src/php --strip-components=1; \
# php ext
    mkdir -p /opt/src/php/ext/redis /opt/src/php/ext/swoole; \
    tar zxf phpredis-5.0.2.tar.gz -C /opt/src/php/ext/redis --strip-components=1; \
    tar zxf swoole-src-4.4.6.tar.gz -C /opt/src/php/ext/swoole --strip-components=1; \
# php
    mkdir -p /opt/bin; \
    mkdir -p /opt/bin/conf.d; \
    cd /opt/src/php; \
    ./buildconf --force; \
    ./configure --help | grep swoole; \
    (./configure \
#        LIBS="$( \
#            pkg-config --libs --static \
#                libcurl \
#                libsodium libargon2 libcrypto++ krb5 \
#        )" \
#        PHP_LDFLAGS=-all-static \
        CFLAGS="-static -fstack-protector-strong -O2" \
        CPPFLAGS="-static -fstack-protector-strong -O2" \
        LDFLAGS="-static -Wl,-O1 -Wl,--hash-style=both" \
#        CFLAGS="-static $PHP_CFLAGS" \
#        LDFLAGS="-static $PHP_LDFLAGS" \
#        CFLAGS="$PHP_CFLAGS" \
#        LDFLAGS="$PHP_LDFLAGS" \
#        CPPFLAGS="$PHP_CPPFLAGS" \
#        --build="$gnuArch" \
        --prefix='/opt/bin' \
        --exec-prefix=/opt/bin \
#        --with-libdir="lib/$debMultiarch" \
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
        --enable-json \
        \
#        --with-curl \
        --with-readline \
        --with-libedit \
        --with-openssl \
        --with-zlib \
# 第三方扩展
#        --enable-swoole \
#        --enable-redis \
        \
        ${PHP_EXTRA_CONFIGURE_ARGS:-} \
    ) || (cat config.log && false); \
#    make -j "$(nproc)" PHP_LDFLAGS=-all-static; \
#    make -j "$(nproc)" ; \
    make ; \
    make install;

FROM debian:buster-slim

COPY --from=build /opt/bin /opt/php
#COPY ./docker-php-entrypoint /usr/local/bin/

WORKDIR /opt/php

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list; \
    ls -l bin; \
    /opt/php/bin/php -v; \
    ldd /opt/php/bin/php;

ENTRYPOINT ["bash"]
CMD ["/opt/php/bin/php", "-a"]