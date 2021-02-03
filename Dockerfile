FROM ruby:2.6.5

RUN apt-get update \
  && apt-get install -y default-jre \
  && apt-get purge -y --auto-remove

ADD https://github.com/AsamK/signal-cli/releases/download/v0.7.4/signal-cli-0.7.4.tar.gz ./

RUN tar -xzvf signal-cli-0.7.4.tar.gz -C /opt \
  && rm signal-cli-0.7.4.tar.gz \
  && ln -sf /opt/signal-cli-0.7.4/bin/signal-cli /usr/local/bin/

VOLUME /root/.local/share/signal-cli/data/

RUN mkdir /app
WORKDIR /app

ADD Gemfile* /app/
RUN gem install bundler:2.0.2
RUN bundle install

ADD . /app

EXPOSE 9292

ENTRYPOINT ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "9292"]
