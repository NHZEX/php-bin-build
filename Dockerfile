FROM alpine:3.10 as build

# dependencies required for running "phpize"
# these get automatically installed and removed by "docker-php-ext-*" (unless they're already installed)
ENV PHPIZE_DEPS \
		autoconf \
		dpkg-dev dpkg \
		file \
		g++ \
		gcc \
		libc-dev \
		make \
		pkgconf \
		re2c \
		bison

RUN set -eux; \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    echo "@testing http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories; \
    cat /etc/apk/repositories; \
    apk update;

# persistent / runtime deps
RUN apk add --no-cache \
		ca-certificates \
		curl \
		tar \
		xz \
# https://github.com/docker-library/php/issues/494
		openssl

# persistent / runtime deps
#RUN set -eux; \
#	apk add --no-cache \
#		apr-dev \
#        apr-util-dev \
#        aspell-dev \
#        autoconf \
#        bison \
#        bzip2-dev \
#        bzip2-static@testing \
#        curl-dev \
#        curl-static \
#        db-dev \
#        enchant-dev \
#        expat-dev \
#        freetds-dev \
#        freetype-dev \
#        freetype-static \
#        g++ \
#        gdbm-dev \
#        gmp-dev \
#        icu-dev \
#        icu-static \
#        libevent-dev \
#        libevent-static \
#        libgcrypt-dev \
#        libgd \
#        libjpeg-turbo-dev \
#        libmcrypt-dev \
#        libpng-dev \
#        libpng-static \
#        libssh2-dev \
#        libtool \
#        libxml2-dev \
#        libxslt-dev \
#        libzip-dev \
#        make \
#        mariadb-dev \
#        net-snmp-dev \
#        nghttp2-dev \
#        nghttp2-static \
#        openldap-dev \
#        openssl-dev \
#        openssl-libs-static@testing \
#        readline-dev \
#        sqlite-dev \
#        sqlite-static \
#        unixodbc-dev \
#        zlib-dev \
#        zlib-static@testing \
#	;

RUN set -eux; \
    apk add --no-cache \
        readline \
        readline-dev \
        libedit \
        libedit-dev \
        libsodium-dev \
        argon2-dev \
        ncurses \
    ;

# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# Adds GNU HASH segments to generated executables (this is used if present, and is much faster than sysv hash; in this configuration, sysv hash is also generated)
# https://github.com/docker-library/php/issues/272
ENV PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
ENV PHP_CPPFLAGS="$PHP_CFLAGS"
ENV PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie"


ENV PHP_INI_DIR .
ENV PHP_VERSION 7.2.22

WORKDIR /opt
COPY src /opt/src

RUN set -eux; \
	apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		argon2-dev \
		coreutils \
		curl-dev \
		libedit-dev \
		libsodium-dev \
		libxml2-dev \
		openssl-dev \
		sqlite-dev \
	;

RUN set -eux; \
    apk add --no-cache \
        sqlite-dev \
    ;

RUN set -eux; \
# src
    cd /opt/src && ls -l; \
    mkdir -p /opt/src/php; \
    tar zxf php-src-php-7.2.22.tar.gz -C /opt/src/php --strip-components=1; \
# php ext
    mkdir -p /opt/src/php/ext/redis /opt/src/php/ext/swoole; \
    tar zxf phpredis-5.0.2.tar.gz -C /opt/src/php/ext/redis --strip-components=1; \
    tar zxf swoole-src-4.4.8.tar.gz -C /opt/src/php/ext/swoole --strip-components=1; \
# 映射
    ln -s /usr/include/libxml2/libxml/ /usr/include/libxml; \
# php
    mkdir -p /opt/bin; \
    mkdir -p /opt/bin/conf.d; \
    cd /opt/src/php; \
    ./buildconf --force; \
    ./configure --help | grep swoole; \
    export CFLAGS="-static $PHP_CFLAGS" \
    		CPPFLAGS="$PHP_CPPFLAGS" \
    		LDFLAGS="-static $PHP_LDFLAGS" \
    	; \
    mkdir -p "$PHP_INI_DIR/conf.d"; \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
    (./configure \
            LIBS="$( \
                pkg-config --libs --static \
            )" \
     		--build="$gnuArch" \
     		--prefix='/opt/bin' \
     		--exec-prefix=/opt/bin \
     		--with-config-file-path="$PHP_INI_DIR" \
     		--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
     		\
     # 静态编译
            --enable-static \
     		\
     # make sure invalid --configure-flags are fatal errors intead of just warnings
     		--enable-option-checking=fatal \
     		\
     # https://github.com/docker-library/php/issues/439
     		--with-mhash \
     		\
     # --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
     		--enable-ftp \
     # --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
     		--enable-mbstring \
     # --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
     		--enable-mysqlnd \
     # https://wiki.php.net/rfc/argon2_password_hash (7.2+)
     		--with-password-argon2 \
     # https://wiki.php.net/rfc/libsodium
     		--with-sodium=shared \
     # always build against system sqlite3 (https://github.com/php/php-src/commit/6083a387a81dbbd66d6316a3a12a63f06d5f7109)
     		--with-pdo-sqlite=/usr \
     		--with-sqlite3=/usr \
     		\
     		--with-curl \
     		--with-libedit \
     		--with-openssl \
     		--with-zlib \
     		\
    # 外部扩展
            --enable-swoole \
#            --enable-redis \
     # bundled pcre does not support JIT on s390x
     # https://manpages.debian.org/stretch/libpcre3-dev/pcrejit.3.en.html#AVAILABILITY_OF_JIT_SUPPORT
     		$(test "$gnuArch" = 's390x-linux-musl' && echo '--without-pcre-jit') \
     		\
     		${PHP_EXTRA_CONFIGURE_ARGS:-} \
     	; \
    ) || (cat config.log && false); \
    make -j "$(nproc)" PHP_LDFLAGS=-all-static; \
    make install;

FROM debian:buster-slim

COPY --from=build /opt/bin /opt/php
#COPY ./docker-php-entrypoint /usr/local/bin/

WORKDIR /opt/php

RUN sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list; \
    ls -l bin; \
    ldd /opt/php/bin/php;

ENTRYPOINT ["bash"]
CMD ["/opt/php/bin/php", "-a"]