#build stage

FROM alpine AS builder


#env variable

ENV log4shib_version 2.0.0
ENV zlib_version 1.2.11
ENV curl_version 7.74.0
ENV xerces_version 3.2.3
ENV xmlsecurity_version 2.0.2
ENV xmltooling_version 3.2.0
ENV opensaml_version 3.2.0
ENV shibbolethsp_version 3.2.2


#prepare tools
RUN apk add --no-cache --virtual .build-deps \
  gcc \
  libc-dev \
  make \
  openssl \
  openssl-dev \
  pcre-dev \
  zlib-dev \
  linux-headers \
  curl \
  gnupg \
  libxslt-dev \
  gd-dev  \
  g++ \
  git \
  fcgi-dev


####    １段階目に必要なファイルのダウンロード (参考:https://wiki.shibboleth.net/confluence/display/SP3/LinuxBuild) #####

RUN curl -L -o /tmp/log4shib-2.0.0.tar.gz  "https://shibboleth.net/downloads/log4shib/latest/log4shib-2.0.0.tar.gz" && \
  curl -L -o /tmp/zlib-1.2.11.tar.gz  "https://zlib.net/zlib-1.2.11.tar.gz" && \
  curl -L -o /tmp/curl-7.74.0.tar.gz  "https://curl.se/download/curl-7.74.0.tar.gz" && \
  curl -L -o /tmp/xerces-c-3.2.3.tar.gz  "https://downloads.apache.org/xerces/c/3/sources/xerces-c-3.2.3.tar.gz" && \
  curl -L -o /tmp/xml-security-c-2.0.2.tar.gz  "https://downloads.apache.org/santuario/c-library/xml-security-c-2.0.2.tar.gz" && \
  curl -L -o /tmp/xmltooling-3.2.0.tar.gz  "http://shibboleth.net/downloads/c++-opensaml/3.2.0/xmltooling-3.2.0.tar.gz" && \
  curl -L -o /tmp/opensaml-3.2.0.tar.gz "https://shibboleth.net/downloads/c++-opensaml/latest/opensaml-3.2.0.tar.gz" && \
  curl -L -o /tmp/shibboleth-sp-${shibbolethsp_version}.tar.gz  "https://shibboleth.net/downloads/service-provider/latest/shibboleth-sp-${shibbolethsp_version}.tar.gz"


# unarchive source codes

RUN mkdir -p /usr/src
WORKDIR /usr/src
RUN tar -zxf /tmp/log4shib-2.0.0.tar.gz && \
  tar -zxf /tmp/zlib-1.2.11.tar.gz 

RUN tar -zxf /tmp/curl-7.74.0.tar.gz && \
  tar -zxf /tmp/xerces-c-3.2.3.tar.gz && \
  tar -zxf /tmp/xml-security-c-2.0.2.tar.gz  && \
  tar -zxf /tmp/xmltooling-3.2.0.tar.gz &&  \
  tar -zxf /tmp/opensaml-3.2.0.tar.gz && \
  tar -zxf /tmp/shibboleth-sp-${shibbolethsp_version}.tar.gz 


# install boost

RUN apk add boost-dev

#compile install

RUN cd /usr/src/log4shib-2.0.0 && ./configure --disable-static --disable-doxygen && make && make install &&\
cd ../zlib-1.2.11 && ./configure  && make && make install
RUN cd curl-7.74.0 && ./configure --disable-static --enable-thread --without-ca-bundle  && make && make install &&\
cd ../xerces-c-3.2.3 && ./configure  && make && make install 

RUN cd /usr/src/xml-security-c-2.0.2 && ./configure --without-xalan --disable-static  && make && make install 

ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig 
RUN cd /usr/src/xmltooling-3.2.0 && ./configure --with-log4shib=/usr/local -C && make && make install &&\
cd ../opensaml-3.2.0 && ./configure --with-log4shib=/usr/local -C && make && make install &&\
cd ../shibboleth-sp-${shibbolethsp_version} && ./configure --with-log4shib=/usr/local --with-fastcgi && make && make install

#run stage

FROM alpine

#install supervisor

RUN apk add --no-cache supervisor

####
RUN apk add make \
    openssl \
    g++\
    curl
RUN curl -O -k -L https://github.com/FastCGI-Archives/FastCGI.com/raw/master/original_snapshot/fcgi-2.4.1-SNAP-0910052249.tar.gz
RUN tar xf fcgi-2.4.1-SNAP-0910052249.tar.gz
RUN cd fcgi-2.4.1-SNAP-0910052249 && ./configure --prefix=/usr/local && mv libfcgi/fcgio.cpp /tmp/original &&\
 echo "#include <stdio.h>" > libfcgi/fcgio.cpp &&cat /tmp/original >> libfcgi/fcgio.cpp && rm /tmp/original &&\
 make && make install

#copy from build stage 
COPY --from=builder /usr/local /usr/local

# prepare directories

RUN mkdir -p /usr/local/etc/shibboleth/cert
RUN mkdir -p /usr/local/var/run/shibboleth
RUN mkdir -p /usr/local/var/log/shibboleth

COPY server.crt /usr/local/etc/shibboleth/cert/

#setting , preparing supervisord


# supervisord.conf

COPY supervisord.conf /usr/local/etc/supervisor/conf.d/supervisord.conf

# copy testmetadata etc..

COPY 0701IDPmetadata.xml /usr/local/etc/shibboleth/0701IDPmetadata.xml
COPY shibboleth2.xml /usr/local/etc/shibboleth/shibboleth2.xml

CMD ["/usr/bin/supervisord","-c","/usr/local/etc/supervisor/conf.d/supervisord.conf"]

