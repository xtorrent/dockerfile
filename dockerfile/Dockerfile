# centos7 + gko3 tracker dependencies
#
FROM centos:centos7
MAINTAINER Liu Ming <csuliuming@sina.com>

COPY build.sh packages.md5sum /tmp/gko3/

RUN cd /tmp/gko3 && ./build.sh
RUN rm -rf /tmp/gko3
