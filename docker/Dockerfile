FROM fluent/fluentd-kubernetes-daemonset:v1.16-debian-forward-1
USER root
RUN gem install fluent-plugin-lm-logs -v 1.2.8
RUN gem install fluent-plugin-multi-format-parser -v 1.0.0
