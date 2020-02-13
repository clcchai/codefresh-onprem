## Codefresh On-premise installation repository

`cf-onprem` - script that deploys Codefresh application on any kubernetes cluster 

### How it works
`cf-onprem` script reads default variables and environment variables that can override defaults, validates and approves current cluster context, checks if `helm` binary is installed, installs `helm` binary, deploys `codefresh` chart with `helm`.

### Pre-requisites

Before running `cf-onprem` script it is needed to:
* override default environment variables in `env-vars` file if needed
* make configuration changes specific for each customer

There are three files that customize `codefresh` chart deployment:
* `values.yaml.tpl` contains template of values.yaml for different parameters for chart customization


### How to run
1. Clone [onprem](https://github.com/codefresh-io/onprem) repository
```
git clone git@github.com:codefresh-io/onprem.git
cd onprem
```
2. cp `values.yaml.tpl`  `values.yaml`

3. Edit values.yaml
Mandatory to set `global.appUrl` and `firebaseToken` 

    ##### Running on local volumes
        Codefresh can run on local volumes - https://kubernetes.io/docs/concepts/storage/volumes/#local  

        To create local volumes edit `local-volumes/values.yaml`, set:
        - defaultNodeSelector
        - mkdirPods.nodes

        then run `local-volumes/create-local-pvcs.sh`
        edit values.yaml and set the values for `existingPvc`s

4. Web SSL Certificates
installer configures ingress tls patameters accorfing to  "tls" key in values.yaml

```yaml
# default values
tls:
  selfSigned: false
  cert: certs/ssl.crt
  key: certs/private.key
```

if ssl.selfSigned=false (default) installer validates and uses values of ssl.cert and ssl.key.
Certifaicate and key files should exist in the specified location.
Otherwise if ssl.selfSigned=true it generates selfsigned certificates with CN=<global.appUrl>


4. run Intaller:

 ```
 ./cf-onprem [parameters]
 ```
You can also use `env-vars` file to set parameters for your installation


 Example 1 - from dev repo channel specific version :
 ```
 ./cf-onprem --namespace codefresh --repo-channel dev --version 1.0.90
 ```

Example 2: - rerun jobs

./cf-onprem --set global.seedJobs=true --set global.certsJobs=true


    On first run the installers invokes Validator chart which validates:
    - values.yaml
    - ability to launch persistent services on specified storage classes
    - ability to launch persistent services on specified existing pvcs

   the validator can be run separately by `./run-validator.sh`

Example 3 - from downloaded helm chart with private registry and downloaded helm 
```
helm repo add codefresh-onprem-dev http://charts.codefresh.io/dev
helm fetch codefresh-onprem-dev/codefresh
./cf-onprem --helm-chart codefresh-1.0.90.tgz  --reg-user admin --reg-password <password> --private-registry docker-local.jfrog1.cf-cd.com/
```

Example 4 - from chart saved in chart/codefresh

```
./cf-onprem --helm-chart chart/codefresh --private-registry artifactory.six-group.net/ --reg-user xxxxxx --reg-password xxxxxxxx
```

5. Register docker node
```
oc create -f runtime-environment/register-node-job.yaml
```
Note: if it shows error that job already exists, just `oc delete  register-consul-test-node-<num>` or change job name in the yaml

