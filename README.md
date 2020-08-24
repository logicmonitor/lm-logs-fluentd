
# lm-logs-fluentd (beta)
This output plugin sends Fluentd records to the configured LogicMonitor account.

## Prerequisites

Install with gem:       `gem install lm-logs-fluentd`

For deb packages:       `td-agent-gem install lm-logs-fluentd`

Alternative: Add `out_lm.rb` to your Fluentd plugins directory.

## Configure the output plugin

Create a custom `fluent.conf` or edit the existing one to specify which logs should be forwarded to LogicMonitor.

```
# Match events tagged with "lm.**" and
# send them to LogicMonitor
<match lm.**>
    @type lm
    company_name <your_company_name>
    resource_mapping {"<event_key>": "<lm_property>"}
    access_id <your_lm_access_id>
    access_key <your_lm_access_key>
    flush_interval 1s
    debug false
</match>
```

### Request example

Sending:

`curl -X POST -d 'json={"message":"hello LogicMonitor from fluentd", "event_key":"lm_property_value"}' http://localhost:8888/lm.test`

Returns the event:
```
{
    "message": "hello LogicMonitor from fluentd"
}
```

**Note:** Make sure that logs have a message field. Requests sent without a message will not be accepted. 

### Resource mapping examples

- `{"message":"Hey!!", "event_key":"lm_property_value"}` with mapping `{"event_key": "lm_property"}`
- `{"message":"Hey!!", "a":{"b":{"c":"lm_property_value"}} }` with mapping `{"a.b.c": "lm_property"}`
- `{"message":"Hey!!", "_lm.resourceId": { "lm_property_name" : "lm_property_value" } }`  this will override resource mapping.

## LogicMonitor properties

| Property | Description |
| --- | --- |
| `company_name` | LogicMonitor account name. |
| `resource_mapping` | The mapping that defines the source of the log event to the LM resource. In this case, the `<event_key>` in the incoming event is mapped to the value of `<lm_property>`.|
| `access_id` | LM API Token access ID. |
| `access_key` | LM API Token access key. |
| `flush_interval` | Defines the time in seconds to wait before sending batches of logs to LogicMonitor. Default is `60s`. |
| `debug` | When `true`, logs more information to the fluentd console. |

