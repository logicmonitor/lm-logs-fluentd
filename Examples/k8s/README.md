## Send k8s logs to Logic Monitor

#### Prerequisite
- Logic Monitor collector [installed](https://www.logicmonitor.com/support/monitoring/containers/kubernetes/adding-your-kubernetes-cluster-into-monitoring). 


#### Deploy
Run the following command to deploy
`helm install -n <namespace> lm-k8s-fluent --set lm_company_name=<lm_company_name> --set "lm_access_id=<access_id>" --set "lm_access_key=<access_key>" .`

##### Note
- In `values.yaml` image is hardcoded to **lmmuhammadahsan/lm-logs-k8s-fluentd** for this example. You can build the DockerFile and publish to registry, replace the name in `values.yaml`
- Fluentd configuration is in `configmap.yaml`.