FROM ruby:latest
RUN mkdir /logicmonitor
COPY ./ logicmonitor
WORKDIR /logicmonitor
RUN bundle install
RUN gem build lm-logs-fluentd.gemspec
RUN mv lm-logs-fluentd-*.gem release.gem