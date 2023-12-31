# FROM nimlang/nim:2.0.0-alpine-onbuild
FROM hub.hamdocker.ir/nimlang/nim:2.0.0-alpine-onbuild

# install timezones database
RUN apk add tzdata
# set timezone to Iran
RUN cp /usr/share/zoneinfo/Iran  /etc/localtime

# install ssl library
RUN apk add openssl-dev 

# prepare app
WORKDIR /app
COPY . /app/

RUN nimble prepare
# RUN nimble db
RUN nimble make
RUN nimble done
CMD ["./bin/main.exe", "--bale"]
