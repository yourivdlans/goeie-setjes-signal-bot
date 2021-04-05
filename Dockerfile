FROM ruby:2.6.5

RUN apt-get update \
  && apt-get install -y default-jre dbus \
  && apt-get purge -y --auto-remove

ADD https://github.com/AsamK/signal-cli/releases/download/v0.8.1/signal-cli-0.8.1.tar.gz ./

RUN tar -xzvf signal-cli-0.8.1.tar.gz -C /opt \
  && rm signal-cli-0.8.1.tar.gz \
  && ln -sf /opt/signal-cli-0.8.1/bin/signal-cli /usr/local/bin/

VOLUME /root/.local/share/signal-cli/data/

RUN mkdir /app
WORKDIR /app

ADD Gemfile* /app/
RUN gem install bundler:2.2.9
RUN bundle install --without test

ADD . /app

ENTRYPOINT "./run.sh"
