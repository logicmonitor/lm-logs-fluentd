
[![Gem Version](https://badge.fury.io/rb/fluent-plugin-lm-logs.svg)](http://badge.fury.io/rb/fluent-plugin-lm-logs)
# lm-logs-fluentd
This output plugin sends Fluentd records to the configured LogicMonitor account.

## Prerequisites

Install the plugin:
* With gem (if td-agent/fluentd is installed along with native ruby):       `gem install fluent-plugin-lm-logs`
* For native td-agent/fluentd plugin handling:       `td-agent-gem install fluent-plugin-lm-logs`

Alternatively, you can add `out_lm.rb` to your Fluentd plugins directory.

## Configure the output plugin

Create a custom `fluent.conf` or edit the existing one to specify which logs should be forwarded to LogicMonitor.

```
# Match events tagged with "lm.**" and
# send them to LogicMonitor
<match lm.**>
    @type lm
    resource_mapping {"<event_key>": "<lm_property>"}
    company_name <lm_company_name>
    company_domain <lm_company_domain>
    access_id <lm_access_id>
    access_key <lm_access_key>
    resource_type <resource_type>
      <buffer>
        @type memory
        flush_interval 1s
        chunk_limit_size 5m
      </buffer> 
    debug false
</match>
```

### Request example

Sending:

`curl -X POST -d 'json={"message":"hello LogicMonitor from fluentd", "event_key":"lm_property_value"}' http://localhost:8888/lm.test`

Produces this event:
```
{
    "message": "hello LogicMonitor from fluentd"
}
```

**Note:** Make sure that logs have a message field. Requests sent without a message will not be accepted. 

### Kubernetes
The Kubernetes configuration for LM Logs is deployed as a Helm chart.
See the [LogicMonitor Helm repository](https://github.com/logicmonitor/k8s-helm-charts/tree/master/lm-logs).

### Resource mapping examples

- `{"message":"Hey!!", "event_key":"lm_property_value"}` with mapping `{"event_key": "lm_property"}`
- `{"message":"Hey!!", "a":{"b":{"c":"lm_property_value"}} }` with mapping `{"a.b.c": "lm_property"}`
- `{"message":"Hey!!", "_lm.resourceId": { "lm_property_name" : "lm_property_value" } }`  this will override resource mapping.

## LogicMonitor properties

| Property | Description |
| --- | --- |
| `company_name` | LogicMonitor account name. |
| `company_domain` | LogicMonitor account domain. For eg. for url test.logicmonitor.com, company_domain is logicmonitor.com . Default is `logicmonitor.com`. |
| `resource_mapping` | The mapping that defines the source of the log event to the LM resource. In this case, the `<event_key>` in the incoming event is mapped to the value of `<lm_property>`.|
| `access_id` | LM API Token access ID. |
| `access_key` | LM API Token access key. |
| `resource_type` | If a Resource Type is specified, it will be statically applied to all ingested logs. If left blank, Resource Type field will be empty. |
| `bearer_token` | LM API Bearer Token. Either specify `access_id` and `access_key` both or `bearer_token`. If all specified, LMv1 token(`access_id` and `access_key`) will be used for authentication with Logicmonitor. |
| `flush_interval` | Defines the time in seconds to wait before sending batches of logs to LogicMonitor. Default is `60s`. |
| `debug` | When `true`, logs more information to the fluentd console. |
| `force_encoding` | Specify charset when logs contains invalid utf-8 characters. |
| `include_metadata` | When `true`, appends additional metadata to the log. default `false`.  |
| `device_less_logs` | When `true`, do not map log with any resource. record must have `service` when `true`. default `false`. |
| `http_proxy` | http proxy string eg. `http://user:pass@proxy.server:port`. Default `nil`  |



