FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
COPY tools/install.sh /tmp/install.sh
RUN sh /tmp/install.sh
# Téléchargement de WordPress dans un dossier de "stock" (pas le volume)
RUN curl -o /tmp/wordpress.tar.gz https://wordpress.org/latest.tar.gz && \
tar -xzf /tmp/wordpress.tar.gz -C /usr/src/ && \
rm /tmp/wordpress.tar.gz
COPY conf/www.conf /etc/php/7.4/fpm/pool.d/www.conf
COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh
EXPOSE 9000
ENTRYPOINT [ "/usr/local/bin/init.sh" ]
