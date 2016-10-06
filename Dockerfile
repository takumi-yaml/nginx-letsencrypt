FROM nginx:alpine

#We need to install bash to easily handle arrays
# in the entrypoint.sh script
RUN apk add --update bash \
  python python-dev py-pip \
  gcc musl-dev linux-headers \
  augeas-dev openssl-dev libffi-dev ca-certificates dialog \
  && rm -rf /var/cache/apk/*

RUN pip install -U letsencrypt

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

# used for webroot reauth
RUN mkdir -p /etc/letsencrypt/webrootauth

ADD entrypoint.sh /entrypoint.sh

ENV EMAIL=''
ENV DOMAIN=''
ENV UPSTREAM=''


EXPOSE 80 443

ENTRYPOINT ["/entrypoint.sh"]
