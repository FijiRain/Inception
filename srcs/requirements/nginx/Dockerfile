From debian:bookworm-slim

ARG DOMAIN_NAME

ENV DEBIAN_FRONTEND=noninteractive

COPY tools/install.sh /tmp/install.sh
RUN sh /tmp/install.sh

RUN mkdir -p /etc/nginx/ssl

RUN openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/wordpress.key \
    -out /etc/nginx/ssl/wordpress.crt \
    -subj "/CN=${DOMAIN_NAME}"

COPY conf/nginx.conf /etc/nginx/sites-available/default

RUN sed -i "s/server_name .*/server_name ${DOMAIN_NAME};/" /etc/nginx/sites-available/default

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]

