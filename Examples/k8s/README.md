## Send k8s logs to Logic Monitor

#### Prerequisite
- Logic Monitor collector [installed](https://www.logicmonitor.com/support/monitoring/containers/kubernetes/adding-your-kubernetes-cluster-into-monitoring). 


#### Deploy
Add helm repo

``` console
helm repo add lm-logs-fluent https://logicmonitor.github.io/lm-logs-fluentd/
```

Install chart

``` console
helm install -n <<namespace>> \
--set lm_company_name="<<lm_company_name-name>>" \
--set lm_access_id="<<lm_access_id>>" \
--set lm_access_key="<<lm_access_key>>" \
lm-k8s-fluent lm-logs-fluent/lm-k8s-fluent
```