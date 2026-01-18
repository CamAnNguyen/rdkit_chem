# syntax=docker/dockerfile:1

FROM ruby:3.3.4-slim AS base

WORKDIR /rails

# Install base packages and build dependencies in one layer to keep the image slim
RUN apt-get update -qq && \
  apt-get install --no-install-recommends -y \
  build-essential \
  git \
  cmake \
  swig \
  pkg-config \
  curl \
  libvips \
  libmagickwand-dev \
  libpq-dev \
  libboost-all-dev \
  libreadline-dev \
  libyaml-dev \
  postgresql-client \
  chromium \
  imagemagick \
  openjdk-17-jre-headless && \
  rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ENV RAILS_ENV="production" \
  BUNDLE_DEPLOYMENT="1" \
  BUNDLE_PATH="/usr/local/bundle" \
  BUNDLE_WITHOUT="development:test" \
  DEBIAN_FRONTEND="noninteractive"

# Update system gems
RUN gem update --system --no-document && \
  gem install -N bundler

# Copy only Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle config set specific_platform true && \
  bundle config set --local without 'development test' && \
  bundle install --jobs $(nproc) --retry 3 && \
  bundle clean && \
  rm -rf /usr/local/bundle/cache

RUN gem install overmind

# Clean up build dependencies to keep the image slim
# Note: openjdk-17-jre-headless is kept for OPSIN service
RUN apt-get remove -y build-essential git cmake swig pkg-config && \
  apt-get autoremove -y && \
  rm -rf /var/lib/apt/lists/*

# Create and switch to non-root user
# RUN groupadd --system --gid 1000 rails && \
#   useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

# USER 1000:1000
