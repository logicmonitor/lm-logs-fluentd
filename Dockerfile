FROM ruby:latest
RUN mkdir /logicmonitor
COPY ./ logicmonitor
WORKDIR /logicmonitor
RUN bundle install \
&& gem build lm-logs-fluentd.gemspec \
&& mv lm-logs-fluentd-*.gem release.gem
