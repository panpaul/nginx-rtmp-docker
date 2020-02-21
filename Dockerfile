# Builer Image
FROM alpine:latest AS builder

# Versions of Nginx and nginx-rtmp-module to use
ENV NGINX_VERSION nginx-1.17.8
ENV NGINX_RTMP_MODULE_VERSION 1.2.1

# Install dependencies
RUN sed -i apk add --no-cache ca-certificates openssl openssl-dev gcc g++ pcre-dev zlib-dev make

# Download and decompress Nginx
RUN mkdir -p /tmp/build/nginx && \
    cd /tmp/build/nginx && \
    wget -O ${NGINX_VERSION}.tar.gz https://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxf ${NGINX_VERSION}.tar.gz

# Download and decompress RTMP module
RUN mkdir -p /tmp/build/nginx-rtmp-module && \
    cd /tmp/build/nginx-rtmp-module && \
    wget -O nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    tar -zxf nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    cd nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}

# Build and install Nginx
# The default puts everything under /usr/local/nginx, so it's needed to change
# it explicitly. Not just for order but to have it in the PATH
RUN cd /tmp/build/nginx/${NGINX_VERSION} && \
    ./configure \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx/nginx.pid \
        --lock-path=/var/lock/nginx/nginx.lock \
        --http-log-path=/var/log/nginx/access.log \
        --http-client-body-temp-path=/tmp/nginx-client-body \
        --with-http_ssl_module \
        --with-threads \
        --add-module=/tmp/build/nginx-rtmp-module/nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION} && \
    sed -i 's/-Werror//g' /tmp/build/nginx/${NGINX_VERSION}/objs/Makefile && \
    make -j $(getconf _NPROCESSORS_ONLN) && \
    make install && \
    mkdir /var/lock/nginx && \
    rm -rf /tmp/build

# The main image
FROM alpine:latest

# Install dependencies
RUN apk add --no-cache ca-certificates openssl pcre

# Copy files from builder
COPY --from=builder /usr/local/nginx /usr/local/nginx
COPY --from=builder /etc/nginx /etc/nginx
RUN mkdir /var/log/nginx && \
    mkdir /var/lock/nginx && \
    mkdir /var/run/nginx

# Forward logs to Docker
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log
    
# Set up config file
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 1935
CMD ["/usr/local/nginx/sbin/nginx", "-g", "daemon off;"]
