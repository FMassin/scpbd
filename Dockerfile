FROM amd64/debian:stable-slim

LABEL org.opencontainers.image.authors="fmassin@sed.ethz.ch"

ENV    WORK_DIR /home/sysop/
ENV INSTALL_DIR /opt/seiscomp
ENV     SCPBTAG seiscomp4+

# Fix Debian  env
ENV DEBIAN_FRONTEND noninteractive
ENV INITRD No
ENV FAKE_CHROOT 1

# Setup sysop's user and group id
ENV USER_ID 1000
ENV GROUP_ID 1000

WORKDIR $WORK_DIR

RUN echo 'force-unsafe-io' | tee /etc/dpkg/dpkg.cfg.d/02apt-speedup \
    && echo 'DPkg::Post-Invoke {"/bin/rm -f /var/cache/apt/archives/*.deb || true";};' | tee /etc/apt/apt.conf.d/no-cache \
    && apt-get update \
    && apt-get dist-upgrade -y --no-install-recommends 

## Install generic tools
RUN apt-get update && \
    apt-get install -y \
        openssh-server \
        openssl \
        libssl-dev \
        net-tools \
        python3 \
        python3-pip \
        sudo \
        wget \
        git \
        pipx

## Install GSM dependencies
RUN pip install configparser cryptography humanize natsort python-dateutil pytz requests tqdm tzlocal urllib3 bs4 --break-system-packages

## Install faketime playback dependencies 
RUN apt-get install -y \
    sqlite3 \
    libfaketime

## Install obspy deps of mseed2key
RUN pip install obspy --break-system-packages

# Cleanup
RUN apt-get autoremove -y --purge \
    && apt-get clean 

# Setup ssh access
RUN mkdir /var/run/sshd
RUN echo 'root:password' | chpasswd
RUN echo X11Forwarding yes >> /etc/ssh/sshd_config
RUN echo X11UseLocalhost no  >> /etc/ssh/sshd_config
RUN echo AllowAgentForwarding yes >> /etc/ssh/sshd_config
RUN echo PermitRootLogin yes >> /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

RUN groupadd --gid $GROUP_ID -r sysop && useradd -m -s /bin/bash --uid $USER_ID -r -g sysop sysop \
    && echo 'sysop:sysop' | chpasswd 

RUN mkdir -p /home/sysop/.seiscomp \
    && chown -R sysop:sysop /home/sysop

## Start sshd
RUN passwd -d sysop
RUN sed -i'' -e's/^#PermitRootLogin prohibit-password$/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i'' -e's/^#PasswordAuthentication yes$/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i'' -e's/^#PermitEmptyPasswords no$/PermitEmptyPasswords yes/' /etc/ssh/sshd_config \
    && sed -i'' -e's/^UsePAM yes/UsePAM no/' /etc/ssh/sshd_config 

RUN echo $INSTALL_DIR \
    && mkdir -p $INSTALL_DIR \
    && chown -R sysop:sysop $INSTALL_DIR/../ \
    && chmod g+w $INSTALL_DIR/../
    
USER sysop

## Install GSM
RUN wget https://data.gempa.de/gsm/gempa-gsm.tar.gz &&\
    tar xvfz gempa-gsm.tar.gz 

COPY gsmsetup gsm/

## Install SeisComP
RUN rm -rf gsm/sync &&\
    cd gsm && \
    bash ./gsmsetup 

USER root

## Install SeisComP deps and database
RUN sed -i 's;apt;apt -y;' $INSTALL_DIR/share/deps/*/*/install-*.sh
RUN $INSTALL_DIR/bin/seiscomp install-deps base gui mariadb-server

RUN /etc/init.d/mariadb start && \
    sleep 5 && \
    mysql -u root -e "CREATE DATABASE seiscomp" && \
    mysql -u root -e "CREATE USER 'sysop'@'localhost' IDENTIFIED BY 'sysop'" && \
    mysql -u root -e "GRANT ALL PRIVILEGES ON * . * TO 'sysop'@'localhost'" && \
    mysql -u root -e "FLUSH PRIVILEGES" && \
    mysql -u root seiscomp <  $INSTALL_DIR/share/db/mysql.sql

USER sysop

RUN $INSTALL_DIR/bin/seiscomp print env >> /home/sysop/.bashrc

## Setup faketime playback
RUN git clone --branch "$SCPBTAG" https://github.com/yannikbehr/sc3-playback  $WORK_DIR"/sc3-playback"

USER root

## Setup main 
COPY bin/* /usr/local/bin/
ADD cfg/ /home/sysop/.seiscomp/

RUN chown -R sysop:root /home/sysop/ $INSTALL_DIR

EXPOSE 18000
#ENTRYPOINT ["/usr/local/bin/main"]
EXPOSE 22
CMD ["sh", "-c", "/usr/sbin/sshd -D"]