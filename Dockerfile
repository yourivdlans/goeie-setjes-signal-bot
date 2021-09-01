FROM ruby:2.6.5

RUN apt-get update \
  && apt-get install -y default-jre dbus \
  && apt-get purge -y --auto-remove

ADD https://github.com/exquo/signal-libs-build/releases/download/v0.8.5/signal-cli-v0.8.5-x86_64-Linux.tar.gz ./

RUN tar -xzvf signal-cli-v0.8.5-x86_64-Linux.tar.gz -C /opt \
  && rm signal-cli-v0.8.5-x86_64-Linux.tar.gz \
  && ln -sf /opt/signal-cli-0.8.5/bin/signal-cli /usr/local/bin/

VOLUME /root/.local/share/signal-cli/data/

RUN mkdir /app
WORKDIR /app

ADD Gemfile* /app/
RUN gem install bundler:2.2.9
RUN bundle config set --local without 'test' \
    && bundle install

ADD . /app

ENTRYPOINT "./run.sh"
