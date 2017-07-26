############################################################
# Dockerfile to build Lenovo Platform Deployer container images
# Based on centos 6
############################################################
FROM centos:centos6
MAINTAINER Ta-Ming Chen
RUN yum -y update
RUN yum makecache fast
RUN yum -y install initscripts
COPY ./shared/RPM-GPG-KEY-LENOVO /etc/pki/rpm-gpg/
COPY ./shared/lenovo-hpc.repo /etc/yum.repos.d/
COPY ./shared/xCAT-2.13.2.POST78.g638d27f-1.x86_64.rpm /tmp/
COPY lci /lci/
COPY ./bin/lpdeploy /usr/local/bin/
RUN yum -y install perl-xCAT.noarch
RUN yum -y install epel-release
RUN yum -y install perl-DBD-SQLite.x86_64
RUN yum -y install xinetd
RUN yum -y install openssh.x86_64
RUN yum -y install openssh-clients.x86_64
RUN yum -y install dhcp.x86_64
RUN yum -y install bind
RUN yum -y install tmux
RUN yum -y install iptables
RUN yum -y install elilo-xcat
RUN yum -y install httpd
RUN yum -y install nfs-utils
RUN yum -y install rsync
RUN yum -y install dnsmasq
RUN yum -y install syslinux
RUN yum -y install syslinux-xcat
RUN yum -y install xnba-undi
RUN yum -y install tftp-server
RUN yum -y install xCAT.x86_64
RUN yum -y install lenovo-confluent
RUN rpm -Uvh --force /tmp/xCAT-2.13.2.POST78.g638d27f-1.x86_64.rpm
CMD /lci/allowall.sh
