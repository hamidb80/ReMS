# FROM nimlang/nim:2.0.2-alpine-onbuild
FROM hub.hamdocker.ir/nimlang/nim:2.0.2-alpine-onbuild

# install timezones database
RUN apk add tzdata
# set timezone to Iran
RUN cp /usr/share/zoneinfo/Iran  /etc/localtime

# install ssl package
RUN apk add openssl-dev 
# install pcre for RegEx
RUN apk add pcre

# prepare app
WORKDIR /app
COPY . /app/

RUN nimble prepare
RUN nimble make
RUN nimble done
CMD ["./bin/main.exe", "--bale"]
