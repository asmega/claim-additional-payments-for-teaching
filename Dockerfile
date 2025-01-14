# ------------------------------------------------------------------------------
# base
# ------------------------------------------------------------------------------
FROM ruby:3.2.4-alpine AS base

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

ENV APP_HOME /app
ENV DEPS_HOME /deps
ENV RAILS_ENV production

RUN apk update
RUN apk add bash postgresql-dev tzdata nodejs curl libc6-compat shared-mime-info

# ------------------------------------------------------------------------------
# dependencies
# ------------------------------------------------------------------------------
FROM base AS dependencies

RUN apk update
RUN apk add build-base git yarn

# Set up install environment
RUN mkdir -p ${DEPS_HOME}
WORKDIR ${DEPS_HOME}

# Install Ruby dependencies
COPY Gemfile ${DEPS_HOME}/Gemfile
COPY Gemfile.lock ${DEPS_HOME}/Gemfile.lock
RUN gem install bundler
ENV BUNDLE_BUILD__SASSC=--disable-march-tune-native
RUN bundle config set frozen 'true'
RUN bundle config set without 'development';
# End

RUN bundle config
RUN bundle install --retry 3

# Install JavaScript dependencies
COPY package.json ${DEPS_HOME}/package.json
COPY yarn.lock ${DEPS_HOME}/yarn.lock
RUN yarn install --frozen-lockfile

# ------------------------------------------------------------------------------
# web
# ------------------------------------------------------------------------------

FROM base AS web

# Set up install environment
RUN mkdir -p ${APP_HOME}
WORKDIR ${APP_HOME}

EXPOSE 3000

CMD /filebeat/filebeat -c /filebeat/filebeat.yml & bundle exec rails server

# Download and install filebeat for sending logs to logstash
ENV FILEBEAT_VERSION=7.6.2
ENV FILEBEAT_DOWNLOAD_PATH=/tmp/filebeat.tar.gz
ENV FILEBEAT_CHECKSUM=482304509aed80db78ef63a0fed88e4453ebe7b11f6b4ab3168036a78f6a413e2f6a5c039f405e13984653b1a094c23f7637ac7daf3da75a032692d1c34a9b65

RUN curl https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${FILEBEAT_VERSION}-linux-x86_64.tar.gz -o ${FILEBEAT_DOWNLOAD_PATH} && \
  [ "$(sha512sum ${FILEBEAT_DOWNLOAD_PATH})" = "${FILEBEAT_CHECKSUM}  ${FILEBEAT_DOWNLOAD_PATH}" ] && \
  tar xzvf ${FILEBEAT_DOWNLOAD_PATH} && \
  rm ${FILEBEAT_DOWNLOAD_PATH} && \
  mv filebeat-${FILEBEAT_VERSION}-linux-x86_64 /filebeat && \
  rm -f /filebeat/filebeat.yml

# Copy our local filebeat config to the installation
COPY filebeat.yml /filebeat/filebeat.yml

# Copy dependencies (relying on dependencies using the same base image as this)
COPY --from=dependencies ${DEPS_HOME}/Gemfile ${APP_HOME}/Gemfile
COPY --from=dependencies ${DEPS_HOME}/Gemfile.lock ${APP_HOME}/Gemfile.lock
COPY --from=dependencies ${GEM_HOME} ${GEM_HOME}
COPY --from=dependencies ${DEPS_HOME}/node_modules ${APP_HOME}/node_modules

# Copy app code (sorted by vague frequency of change for caching)
COPY config.ru ${APP_HOME}/config.ru
COPY Rakefile ${APP_HOME}/Rakefile
COPY public ${APP_HOME}/public
COPY vendor ${APP_HOME}/vendor
COPY bin ${APP_HOME}/bin
COPY lib ${APP_HOME}/lib
COPY config ${APP_HOME}/config
COPY db ${APP_HOME}/db
COPY app ${APP_HOME}/app
COPY spec ${APP_HOME}/spec

RUN DFE_SIGN_IN_API_CLIENT_ID= \
  DFE_SIGN_IN_API_SECRET= \
  DFE_SIGN_IN_API_ENDPOINT= \
  ADMIN_ALLOWED_IPS= \
  ENVIRONMENT_NAME= \
  SUPPRESS_DFE_ANALYTICS_INIT= \
  bundle exec rake assets:precompile

RUN chown -hR appuser:appgroup ${APP_HOME} /filebeat

USER appuser

ARG GIT_COMMIT_HASH
ENV GIT_COMMIT_HASH ${GIT_COMMIT_HASH}

# ------------------------------------------------------------------------------
# shellcheck
# ------------------------------------------------------------------------------

FROM koalaman/shellcheck:stable AS shellcheck

# ------------------------------------------------------------------------------
# test
# ------------------------------------------------------------------------------
FROM base AS test

USER root
WORKDIR ${APP_HOME}

ENV RAILS_ENV test
ENV NODE_ENV test
CMD [ "bundle", "exec", "rake" ]

RUN apk add chromium chromium-chromedriver

# Install ShellCheck
COPY --from=shellcheck / /opt/shellcheck/
ENV PATH /opt/shellcheck/bin:${PATH}

COPY --from=dependencies ${GEM_HOME} ${GEM_HOME}

# Copy from web to include generated assets
COPY --from=web ${APP_HOME} ${APP_HOME}

# Copy all files
# This is only for the test target and ensures that all the files that could be linted locally are also linted on CI.
# We need to be mindful of files that get added to the project, if they are secrets or superfluous we should add them
# to the .dockerignore file.
COPY . ${APP_HOME}/

RUN chown -hR appuser:appgroup ${APP_HOME}

USER appuser
