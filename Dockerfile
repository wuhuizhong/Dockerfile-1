FROM centos:7.5.1804
LABEL maintainer "wojiushixiaobai"
WORKDIR /opt

RUN set -ex \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && localedef -c -f UTF-8 -i zh_CN zh_CN.UTF-8 \
    && export LC_ALL=zh_CN.UTF-8 \
    && echo 'LANG="zh_CN.UTF-8"' > /etc/locale.conf \
    && yum -y install wget gcc epel-release git \
    && yum -y install python36 python36-devel \
    && yum -y localinstall --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm \
    && rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro \
    && rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-1.el7.nux.noarch.rpm \
    && yum install -y java-1.8.0-openjdk libtool \
    && mkdir /usr/local/lib/freerdp/ \
    && ln -s /usr/local/lib/freerdp /usr/lib64/freerdp \
    && yum install -y cairo-devel libjpeg-turbo-devel libpng-devel uuid-devel \
    && yum install -y ffmpeg-devel freerdp-devel freerdp-plugins pango-devel libssh2-devel libtelnet-devel libvncserver-devel pulseaudio-libs-devel openssl-devel libvorbis-devel libwebp-devel ghostscript \
    && yum clean all \
    && rm -rf /var/cache/yum/*

RUN set -ex \
    && yum -y install mariadb mariadb-devel mariadb-server redis nginx \
    && mkdir -p /config/guacamole /config/guacamole/lib /config/guacamole/extensions \
    && wget http://mirrors.hust.edu.cn/apache/tomcat/tomcat-8/v8.5.35/bin/apache-tomcat-8.5.35.tar.gz \
    && tar xf apache-tomcat-8.5.35.tar.gz -C /config \
    && rm -rf apache-tomcat-8.5.35.tar.gz \
    && mv /config/apache-tomcat-8.5.35 /config/tomcat8 \
    && sed -i 's/Connector port="8080"/Connector port="8081"/g' `grep 'Connector port="8080"' -rl /config/tomcat8/conf/server.xml` \
    && sed -i 's/FINE/WARNING/g' `grep 'FINE' -rl /config/tomcat8/conf/logging.properties` \
    && echo "java.util.logging.ConsoleHandler.encoding = UTF-8" >> /config/tomcat8/conf/logging.properties \
    && cd /config \
    && wget https://github.com/ibuler/ssh-forward/releases/download/v0.0.5/linux-amd64.tar.gz \
    && tar xf linux-amd64.tar.gz -C /bin/ \
    && chmod +x /bin/ssh-forward \
    && rm -rf /config/linux-amd64.tar.gz \
    && yum clean all \
    && rm -rf /var/cache/yum/*

RUN set -ex \
    && git clone https://github.com/jumpserver/docker-guacamole.git \
    && cd /opt/docker-guacamole \
    && tar -xzf guacamole-server-0.9.14.tar.gz \
    && cd guacamole-server-0.9.14 \
    && autoreconf -fi \
    && ./configure --with-init-dir=/etc/init.d \
    && make \
    && make install \
    && cd .. \
    && rm -rf guacamole-server-0.9.14.tar.gz guacamole-server-0.9.14 \
    && ldconfig \
    && rm -rf /config/tomcat8/webapps/* \
    && cp guacamole-0.9.14.war /config/tomcat8/webapps/ROOT.war \
    && cp guacamole-auth-jumpserver-0.9.14.jar /config/guacamole/extensions/ \
    && cp root/app/guacamole/guacamole.properties /config/guacamole/ \
    && rm -rf /opt/docker-guacamole

RUN set -ex \
    && git clone https://github.com/jumpserver/jumpserver.git \
    && git clone https://github.com/jumpserver/coco.git \
    && wget https://github.com/jumpserver/luna/releases/download/v1.4.4/luna.tar.gz \
    && tar xf luna.tar.gz \
    && chown -R root:root luna \
    && sed -i "s/START_TIMEOUT = 15/START_TIMEOUT = 30/g" /opt/jumpserver/jms \
    && yum -y install $(cat /opt/jumpserver/requirements/rpm_requirements.txt) \
    && yum -y install $(cat /opt/coco/requirements/rpm_requirements.txt) \
    && python3.6 -m venv /opt/py3 \
    && source /opt/py3/bin/activate \
    && pip install --upgrade pip setuptools \
    && pip install -r /opt/jumpserver/requirements/requirements.txt \
    && pip install -r /opt/coco/requirements/requirements.txt \
    && rm -rf /opt/luna.tar.gz \
    && yum clean all \
    && rm -rf /var/cache/yum/* \
    && rm -rf ~/.cache/pip \
    && mkdir -p /opt/coco/keys \
    && mkdir -p /opt/coco/logs

COPY mysql_init.sh mysql_init.sh

RUN set -ex \
    && mysql_install_db --user=mysql --datadir=/var/lib/mysql \
    && sh /opt/mysql_init.sh \
    && rm -rf /opt/mysql_init.sh

COPY config.py jumpserver/config.py
COPY conf.py coco/conf.py
COPY nginx.conf /etc/nginx/nginx.conf
COPY readme.txt readme.txt
COPY entrypoint.sh /bin/entrypoint.sh
RUN chmod +x /bin/entrypoint.sh

VOLUME /opt/jumpserver/data
VOLUME /opt/coco/keys
VOLUME /config/guacamole/keys
VOLUME /var/lib/mysql

ENV DB_ENGINE=mysql \
    DB_HOST=127.0.0.1 \
    DB_PORT=3306 \
    DB_USER=jumpserver \
    DB_PASSWORD=weakPassword \
    DB_NAME=jumpserver

ENV REDIS_HOST=127.0.0.1 \
    REDIS_PORT=6379 \
    REDIS_PASSWORD=

ENV JUMPSERVER_KEY_DIR=/config/guacamole/keys \
    GUACAMOLE_HOME=/config/guacamole \
    JUMPSERVER_ENABLE_DRIVE=true \
    JUMPSERVER_SERVER=http://127.0.0.1:8080

EXPOSE 2222 80
ENTRYPOINT ["entrypoint.sh"]
