FROM nginx:alpine

WORKDIR /app

COPY . /app


RUN apk update --no-cache && apk upgrade --no-cache && apk add --no-cache bash wget bash coreutils grep && \
    mkdir -p /var/www/html/repomirror/repo && mkdir -p /hive/opt/repomirror && \
    ln -sf /var/www/html/repomirror/repo /var/www/html/repo && \
    mv /app/download_os.sh /usr/bin/download_os && chmod +x /usr/bin/download_os && \
    mkdir -p /var/log/nginx && ln -sf /hive/opt/repomirror/etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf && \
    mv /app/update.sh /usr/bin/update && chmod +x  /usr/bin/update && mv /app/nginx.conf /etc/nginx/conf.d/default.conf && \
    mkdir /var/www/html/repomirror/repo/binary/ && echo '0 * * * *     /usr/bin/update' > /etc/crontabs/root


EXPOSE 80

STOPSIGNAL SIGQUIT

CMD ["sh", "-c", "crond -b -S -l 6 -L /var/log/crond.log && nginx -g 'daemon off;'"]
