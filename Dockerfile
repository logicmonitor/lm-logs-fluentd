FROM ruby:latest
RUN mkdir /logicmonitor
COPY ./ logicmonitor
WORKDIR /logicmonitor
RUN bundle install
RUN gem build lm-logs-fluentd.gemspec