FROM ruby:3.0.3

ARG TARGETPLATFORM
ARG SIGNAL_CLI_VERSION=0.10.5
ARG LIBSIGNAL_CLIENT_VERSION=0.15.0

RUN apt-get update \
  && apt-get install -y openjdk-17-jre dbus zip \
  && apt-get purge -y --auto-remove

ADD https://github.com/AsamK/signal-cli/releases/download/v$SIGNAL_CLI_VERSION/signal-cli-$SIGNAL_CLI_VERSION-Linux.tar.gz ./

RUN tar -xzvf signal-cli-$SIGNAL_CLI_VERSION-Linux.tar.gz -C /opt \
  && rm signal-cli-$SIGNAL_CLI_VERSION-Linux.tar.gz \
  && ln -sf /opt/signal-cli-$SIGNAL_CLI_VERSION/bin/signal-cli /usr/local/bin/

# When building on M1
ADD https://github.com/exquo/signal-libs-build/releases/download/libsignal-client_v$LIBSIGNAL_CLIENT_VERSION/libsignal_jni.so-v$LIBSIGNAL_CLIENT_VERSION-aarch64-unknown-linux-gnu.tar.gz ./
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
      tar -xzvf libsignal_jni.so-v$LIBSIGNAL_CLIENT_VERSION-aarch64-unknown-linux-gnu.tar.gz -C ./ \
      && rm libsignal_jni.so-v$LIBSIGNAL_CLIENT_VERSION-aarch64-unknown-linux-gnu.tar.gz \
      && zip -uj /opt/signal-cli-$SIGNAL_CLI_VERSION/lib/libsignal-client-$LIBSIGNAL_CLIENT_VERSION.jar libsignal_jni.so; \
    fi

VOLUME /root/.local/share/signal-cli/data/

RUN mkdir /app
WORKDIR /app

ADD Gemfile* /app/
RUN gem install bundler:2.2.9
RUN bundle config set --local without 'test' \
    && bundle install

ADD . /app

ENTRYPOINT "./run.sh"
