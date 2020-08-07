
# lm-logs-fluentd (beta)
This plugin sends Fluentd records to the Logic Monitor

## Getting started
- Add `out_lm.rb` to plugins directory

- Add to `fluent.conf`

Minimal configuration:
```
<match lm.**>
    @type lm
    company_name {company_name}
    resource_mapping {"event_key": "lm_property"}
    access_id {lm_access_id}
    access_key {lm_access_key}
    flush_interval 1s
    debug false
</match>
```

To send data by

`curl -X POST -d 'json={"message":"hello Logic Monitor from fluentd", "event_key":"lm_property_value"}' http://localhost:8888/lm.test`

More examples of request

- `{"message":"Hey!!", "event_key":"lm_property_value"}` with mapping `{"event_key": "lm_property"}`
- `{"message":"Hey!!", "_lm.resourceId": { "lm_property_name" : "lm_property_value" } }`  this will override resource mapping.
- `{"message":"Hey!!", "a":{"b":{"c":"lm_property_value"}} }` with mapping `{"a.b.c": "lm_property"}`
