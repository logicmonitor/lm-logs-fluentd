FROM fluent/fluentd-kubernetes-daemonset:v1.14-debian-forward-1
USER root
RUN apt-get update \     
     && apt-get upgrade -y
RUN gem install fluent-plugin-lm-logs -v 1.0.1 \
    && gem install fluent-plugin-multi-format-parser -v 1.0.0