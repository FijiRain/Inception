# belek c bookworm la penultimate, verif si ca marche
FROM debian:bullseye-slim
ENV DEBIAN_FRONTEND=noninteractive
COPY tools/install.sh /tmp/install.sh
RUN sh /tmp/install.sh
EXPOSE 3306
COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh
ENTRYPOINT [ "/usr/local/bin/init.sh" ]