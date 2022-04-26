FROM ruby:3.0.3

RUN apt-get update \
  && apt-get install -y openjdk-17-jre dbus zip \
  && apt-get purge -y --auto-remove

ADD https://github.com/AsamK/signal-cli/releases/download/v0.10.5/signal-cli-0.10.5-Linux.tar.gz ./

RUN tar -xzvf signal-cli-0.10.5-Linux.tar.gz -C /opt \
  && rm signal-cli-0.10.5-Linux.tar.gz \
  && ln -sf /opt/signal-cli-0.10.5/bin/signal-cli /usr/local/bin/

# When building on M1
# ADD https://github.com/exquo/signal-libs-build/releases/download/libsignal-client_v0.15.0/libsignal_jni.so-v0.15.0-aarch64-unknown-linux-gnu.tar.gz ./

# RUN tar -xzvf libsignal_jni.so-v0.15.0-aarch64-unknown-linux-gnu.tar.gz -C ./ \
#   && rm libsignal_jni.so-v0.15.0-aarch64-unknown-linux-gnu.tar.gz \
#   && zip -uj /opt/signal-cli-0.10.5/lib/libsignal-client-0.15.0.jar libsignal_jni.so

VOLUME /root/.local/share/signal-cli/data/

RUN mkdir /app
WORKDIR /app

ADD Gemfile* /app/
RUN gem install bundler:2.2.9
RUN bundle config set --local without 'test' \
    && bundle install

ADD . /app

ENTRYPOINT "./run.sh"
