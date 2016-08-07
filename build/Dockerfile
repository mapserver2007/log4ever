FROM ruby:2.3-alpine
MAINTAINER Ryuichi Tanaka <mapserver2007@gmail.com>

RUN apk add --update git build-base \
  && rm -rf /var/cache/apk/*

RUN gem install bundler && \
  gem install rspec

RUN git clone https://github.com/mapserver2007/log4ever.git && \
  cd log4ever && \
  bundle install

WORKDIR /log4ever
