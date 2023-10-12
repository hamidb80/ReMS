FROM nimlang/nim:1.6.12-alpine-onbuild

# install timezones database
RUN apk add tzdata
# set timezone to Iran
RUN cp /usr/share/zoneinfo/Iran/etc/localtime

# install ssl library
RUN apk add libressl-dev 
RUN apk add openssl-dev 

# prepare app
WORKDIR /app
COPY . /app/

RUN nimble prepare
RUN nimble make
RUN nimble db
CMD ["nimble", "go"]