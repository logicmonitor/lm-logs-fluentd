## Sending Nomad Logs to LogicMonitor using Fluentd
To configure a nomad job to send log files to fluentd, you will need to use the ***fluentd*** log driver in your nomad job file. This log driver allows Nomad to send log messages to fluentd, which can then forward the logs to LogicMonitor for storage and analysis.

Here is an example of how to use the ***fluentd*** log driver in your nomad job file:

```hcl
job "example-job" {
    # ...
    #Configure task and specify fluentd as the logging driver for the task
    task "server" {
        driver = "docker"
        config {
            # ...
            logging {
                type = "fluentd"
                config {
                    fluentd-address = "localhost:24224"
                    labels = "custom-label,nomad-region,nomad-task-name,nomad-job-name,nomad-host-dc,nomad-host"
                }
            }
            labels {
                custom-label="example custom label"
                nomad-region="${NOMAD_REGION}"
                nomad-task-name="${NOMAD_TASK_NAME}"
                nomad-job-name="${NOMAD_JOB_NAME}"
                nomad-host-dc="${node.datacenter}"
                nomad-host="${node.unique.name}"
            }
            ulimit {
                nofile = "40960:40960"
                }
            # ...
        }
    }
}
```
In this example, the ***fluentd*** log driver is used to send log messages to a fluentd instance running on ***localhost*** at port ***24224***. You will need to update the ***fluentd-address*** value to match the address of your fluentd instance.

Once you have added the ***logging*** block to your job file, you can submit the job to Nomad as usual. The Nomad agent will then start sending log messages to fluentd.

To include custom labels in the fluentd record, you will need to specify the ***labels*** parameter in the config block of the ***logging*** stanza in your Nomad job file. The labels parameter should be set to a list of label keys from the ***labels*** parameter specified in the config block of the ***task*** stanza, the specified labels will be added to the fluentd record for each log message.

To receive logs from Nomad, you will need to configure fluentd to listen for incoming log messages from Nomad. The specific configuration will depend on your fluentd setup, but in general, you will need to add a ***source***, ***filter*** and ***match*** sections to your fluentd configuration file to listen for logs from Nomad and route them to the appropriate destination.

Here is an example of a fluentd configuration that can receive logs from Nomad:

```yaml
<source>
  @type forward
  tag lm.nomad
  port 24224
  bind 0.0.0.0
</source>

<filter lm.**>
    @type record_transformer
    <record>
        hostname "192.168.1.1"
        tag ${tag}
        message ${record["log"]}
    </record>
    remove_keys log
</filter>

<match lm.**>
    @type copy
    <store>
      @type lm
      company_name portalname
      access_id "**************"
      access_key "*************"
      flush_interval 1s
      resource_mapping {"hostname": "system.hostname"}
      debug false
      include_metadata true
    </store>
    <store>
      @type stdout
    </store>
</match>
```

In this example, the ***source*** section configures fluentd to listen for incoming logs on all network interfaces at port ***24224***. This is the default port used by the fluentd log driver in Nomad, so you will need to make sure that this matches the ***fluentd-address value*** in your Nomad job file.

The ***filter*** section is used in combination with a match section, where the match section specifies a pattern to match incoming log messages, and the filter section specifies one or more transformations to apply to the matched log messages. In the above example we are setting the message value to the value of the record log field and then removing the log value from the record key list since we no longer need it. We are also specifiying a hostname to use when performing the required resource mapping in the ***match*** section of the fluentd config so LogicMonitor knows what resource the log should be assocaited with.

The ***match*** section specifies a pattern to match log messages from Nomad. In this example, the pattern ***'lm.\*\**** is used, which will match all log messages with a tag that begins with ***lm***.. The matched log messages will then be routed to the LM output plugin, which will send the logs to the specified LogicMonitor portal for ingestion.