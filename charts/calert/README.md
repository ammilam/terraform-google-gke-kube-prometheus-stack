# CAlert
CAlert provides integration from Prometheus Alertmanager to Google Chat (https://github.com/mr-karan/calert). Alertmanager provides many builtin integrations, but Gchat is not one of them.

Alertmanager will be configured to use a webhook configuration, sent to CAlert.  CAlert will queue these requests in Redis and send to the GChat channel configured.

## Prerequisites
In Gchat, configure a webhook on GChat channel:
`Channel Name -> Configure webhooks -> Create webhook`

The webhook endpoint will than be added to a channel in the config.toml of CAlert to route alerts properly.  This will be configured in the values.yaml in the CAlert helm chart:
```
[app.chat.alertmanager-testing]
    notification_url = "https://chat.googleapis.com/v1/spaces/AAAAp7CaiQA/messages?key=AIzaSyDdI0hCZtE6vySjMm-WEfRq3CPzqKqqsHI&token=g8Dtp1kVSEYR3ytJsf7vo5P5-2Ba-VJTSaSF87EY9Gc%3D"
```

## Local Testing
You can deploy the local helm chart to test:
```
kubectl create namespace calert
kubens calert
```

Dry run to validate tmeplates:
```
helm upgrade --install calert --dry-run --debug .
```

Deploy from local repo:
```
helm upgrade --install calert --debug .
```

After confirming the values.yaml contains the correct channel and webhook endpoint, you can manually test the CAlert->GChat integration with the following:
```
k port-forward svc/calert 6000:6000
test/send_alert.sh
```

## Build
Recommended to leverage the Jenkinsfile to build the helm chart, but can be done manually for testing:
```
helm package .
```

## Deployment
CAlert should be deployed as a helper service in each Kubernetes cluster via the packaged helm chart.  This should be deployed in the base addons (https://bitbucket.company.com/projects/KUB/repos/base/browse).
