FROM ruby:latest
RUN mkdir /logicmonitor
COPY ./ logicmonitor
WORKDIR /logicmonitor
RUN gem install fluentd
RUN rake
RUN bundle install
RUN gem build fluent-plugin-lm-logs.gemspec
RUN mv fluent-plugin-lm-logs-*.gem release.gem