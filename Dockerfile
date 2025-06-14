FROM ruby:3.1.4

ARG TARGETPLATFORM
ARG SIGNAL_CLI_VERSION=0.13.15
ARG LIBSIGNAL_CLIENT_VERSION=0.70.0

RUN apt-get update \
  && apt-get install -y dbus zip

RUN apt-get update \
    && wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | apt-key add - \
    && echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list \
    && apt-get update \
    && apt-get install -y temurin-21-jre \
    && apt-get purge -y --auto-remove \
    && rm -rf /var/lib/apt/lists/*

ADD https://github.com/AsamK/signal-cli/releases/download/v$SIGNAL_CLI_VERSION/signal-cli-$SIGNAL_CLI_VERSION.tar.gz ./

RUN tar -xzvf signal-cli-$SIGNAL_CLI_VERSION.tar.gz -C /opt \
  && rm signal-cli-$SIGNAL_CLI_VERSION.tar.gz \
  && ln -sf /opt/signal-cli-$SIGNAL_CLI_VERSION/bin/signal-cli /usr/local/bin/

RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
      curl -LO "https://github.com/exquo/signal-libs-build/releases/download/libsignal_v$LIBSIGNAL_CLIENT_VERSION/libsignal_jni.so-v$LIBSIGNAL_CLIENT_VERSION-aarch64-unknown-linux-gnu.tar.gz" \
      && tar -xzvf libsignal_jni.so-v$LIBSIGNAL_CLIENT_VERSION-aarch64-unknown-linux-gnu.tar.gz \
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

ENTRYPOINT ["/app/run.sh"]
