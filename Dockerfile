# perfSONAR Testpoint

FROM rockylinux/rockylinux:8
ENV container docker

RUN dnf -y install \
    epel-release \
    http://software.internet2.edu/rpms/el8/x86_64/latest/packages/perfsonar-repo-0.11-1.noarch.rpm \
    && dnf config-manager --set-enabled powertools \
    && dnf -y install \
    supervisor \
    rsyslog \
    net-tools \
    sysstat \
    iproute \
    bind-utils \
    tcpdump \
    postgresql-server

# -----------------------------------------------------------------------

#
# PostgreSQL Server
#
# Based on a Dockerfile at
# https://raw.githubusercontent.com/zokeber/docker-postgresql/master/Dockerfile

# Set the environment variables
ENV PGDATA /var/lib/pgsql/data

# Initialize the database
RUN su - postgres -c "/usr/bin/pg_ctl init"

# Overlay the configuration files
COPY postgresql/postgresql.conf /var/lib/pgsql/data/postgresql.conf
COPY postgresql/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf

# Change own user
RUN chown -R postgres:postgres /var/lib/pgsql/data/*

#Start postgresql
RUN su - postgres -c "/usr/bin/pg_ctl start -w -t 60" \
    && dnf install -y perfsonar-testpoint perfsonar-toolkit-security \
    && dnf clean all \
    && rm -rf /var/cache/yum

# End PostgreSQL Setup

RUN openssl req -newkey rsa:2048 -nodes -keyout /etc/pki/tls/private/localhost.key -x509 -days 365 -out /etc/pki/tls/certs/localhost.crt -subj "/C=XX/L=Default City/O=Default Company Ltd"

# -----------------------------------------------------------------------------

# Rsyslog
# Note: need to modify default CentOS7 rsyslog configuration to work with Docker, 
# as described here: http://www.projectatomic.io/blog/2014/09/running-syslog-within-a-docker-container/
COPY rsyslog/rsyslog.conf /etc/rsyslog.conf
COPY rsyslog/listen.conf /etc/rsyslog.d/listen.conf
COPY rsyslog/python-pscheduler.conf /etc/rsyslog.d/python-pscheduler.conf
COPY rsyslog/owamp-syslog.conf /etc/rsyslog.d/owamp-syslog.conf

# -----------------------------------------------------------------------------

RUN mkdir -p /var/log/supervisor 
ADD supervisord.conf /etc/supervisord.conf

# The following ports are used:
# pScheduler: 443
# owamp:861, 8760-9960
# twamp: 862, 18760-19960
# simplestream: 5890-5900
# nuttcp: 5000, 5101
# iperf2: 5001
# iperf3: 5201
EXPOSE 443 861 862 5000-5001 5101 5201 8760-9960 18760-19960

# add pid directory, logging, and postgres directory
VOLUME ["/var/run", "/var/lib/pgsql", "/var/log", "/etc/rsyslog.d" ]

CMD /usr/bin/supervisord -c /etc/supervisord.conf
