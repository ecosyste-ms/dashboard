FROM ruby:3.4.5-alpine

ENV APP_ROOT /usr/src/app
ENV DATABASE_PORT 5432
WORKDIR $APP_ROOT

# * Setup system
# * Install Ruby dependencies
RUN apk add --update \
    build-base \
    netcat-openbsd \
    git \
    nodejs \
    postgresql-dev \
    tzdata \
    curl \
    curl-dev \
    libc6-compat \
    musl-dev \
    yaml-dev \
    libffi-dev \
 && rm -rf /var/cache/apk/* 

 RUN curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Will invalidate cache as soon as the Gemfile changes
COPY Gemfile Gemfile.lock $APP_ROOT/

RUN bundle config --global frozen 1 \
 && bundle config set without 'test' \
 && bundle install --jobs 2

# ========================================================
# Application layer

# Copy application code
COPY . $APP_ROOT

RUN bundle exec bootsnap precompile --gemfile app/ lib/

# Precompile assets for a production environment.
# This is done to include assets in production images on Dockerhub.
RUN SECRET_KEY_BASE=1 RAILS_ENV=production bundle exec rake assets:precompile

# Startup
CMD ["bin/docker-start"]
