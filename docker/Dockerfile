# Use an official Ubuntu base image
FROM ubuntu:22.04

# Install OpenVPN
RUN apt-get update && \
    apt-get install -y openvpn nano net-tools borgbackup openssh-client psmisc inetutils-ping tzdata fuse && \
    rm -rf /var/lib/apt/lists/*

ENV TZ="Europe/Madrid"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN mkdir -p "/usr/local/bin"
COPY bin/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*
RUN mkdir -p "/backup"
WORKDIR /backup

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]