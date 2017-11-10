Introduction
============
A java version of mysql service broker referring to the one from cloudfoundry.  It is ported to be able to running with Kubernetes Service Catalog.

The MySQL Service Broker is actually running in tomcat either as standalone server, or can be deployed into Kubernetes as well.

How To Build and Run the MySQL Service Broker 
============================================
To build the project
```
./gradlew build
```

The build command creates jar file with embedded tomcat container.
```
java -jar build/libs/cf-mysql-java-broker-0.1.0.jar
```
The pre-built servic broker jar file can be found in `pre-build` folder

How to config the MySQL Service Broker
=====================================
By default,
* the tomcat server is listening at port `9000`
* requires local mysql server root user password to be `=[-P0o9i8` as default

The above configuration can be changed by modifying the file under `resources\application.yml`

Routes
======
|Routes|Method|Description|
|------|------|-----------|
|/v2/catalog|GET|Service and its plan details by this broker|
|/v2/service_instances/:id|PUT|create a dedicated database for this service|
|/v2/service_instances/:id|DELETE|delete previously created database for this service|
|/v2/service_instances/:id/service_bindings/:id|PUT|create user and grant privilege for the database associated with service.|
|/v2/service_instances/:id/service_bindings/:id|DELETE|delete the user created previously for this binding.|

Register the MySQL Service Broker in Kubernetes Service Catalog
===============================================================

# Service Catalog in Kubernetes

This document outlines the basic steps to register mysql service broker to Kubernetes service catalog by walking
through a short demo. 

## Step 0 - Prerequisites

### environment requirement

1. kubernetes 1.7 +
2. helm / tiller 2.7.0 +


## Step 1 - Installing the Service Catalog System

Please refer to Kubernetes service catalog installation document [service-catalog](https://github.com/kubernetes-incubator/service-catalog/blob/master/docs/install.md) 
There is also a workthrough document of registering a dummy service broker to Kubernetes service catalog. Go through it to understand and verify how K8S service catalog works. [walkthrough](https://github.com/kubernetes-incubator/service-catalog/blob/master/docs/walkthrough.md) 

## Step 2 - Setup MySQL service broker 
Environment requirement: Need java installed.

1.First setup the mysql server.

```console
[root@~]# apt install mysql-server
```

comment the bind-address in mysql config file:

```console
[root@~]# cat /etc/mysql/mysql.conf.d/mysqld.cnf | grep bind

#bind-address		= 127.0.0.1
```

and the mysql root password must be **=[-P0o9i8**

And need to create a database named **test** by CREATE DATABASE test;


2.Startup the service broker

Compile service broker server or find one in 'pre-build' folder and execute

```console
[root@~]# java -jar cf-mysql-java-broker-0.1.0.jar
```

The default port was 9000, we can use http://<host_ip>:9000/v2/catalog to check if the server was ready.

## Step 3 - Create mysql service broker resource

A MySQL service broker resource must be created first. The service broker resource will be registered to Kubernetes service catalog automatically after that.

```console
[root@~]# kubectl create -f demo/standaloneMySQLSB.yaml

```

Check the broker status


```console
[root@~]# kubectl get clusterservicebroker standalone-mysql-broker -o yaml

Sample output looks like:
apiVersion: servicecatalog.k8s.io/v1beta1
kind: ClusterServiceBroker
metadata:
  creationTimestamp: 2017-11-06T09:20:38Z
  finalizers:
  - kubernetes-incubator/service-catalog
  generation: 1
  name: standalone-mysql-broker
  resourceVersion: "411"
  selfLink: /apis/servicecatalog.k8s.io/v1beta1/clusterservicebrokers/standalone-mysql-broker
  uid: c0e07ae0-c2d3-11e7-b157-0a58ac100508
spec:
  relistBehavior: Duration
  relistDuration: 15m0s
  relistRequests: 0
  url: http://192.168.199.78:9000
status:
  conditions:
  - lastTransitionTime: 2017-11-07T09:20:39Z
    message: Successfully fetched catalog entries from broker.
    reason: FetchedCatalog
    status: "True"
    type: Ready
  reconciledGeneration: 1
```

After service broker resource created, the connection between service catalog and broker server will be created.


## Step 4 - Check the service classes in service catalog

In service catalog, check the new added service classes offered by mysql service broker:

```console
[root@~]# kubectl get clusterserviceclasses -o yaml

Sample output looks like:

apiVersion: v1
items:
- apiVersion: servicecatalog.k8s.io/v1beta1
  kind: ClusterServiceClass
  metadata:
    creationTimestamp: 2017-11-06T09:20:38Z
    name: 3101b971-1044-4816-a7ac-9ded2e028079
    namespace: ""
    resourceVersion: "154"
    selfLink: /apis/servicecatalog.k8s.io/v1beta1/clusterserviceclasses/3101b971-1044-4816-a7ac-9ded2e028079
    uid: c0fe568d-c2d3-11e7-b157-0a58ac100508
  spec:
    bindable: true
    clusterServiceBrokerName: standalone-mysql-broker
    description: MySQL service for application development and testing
    externalID: 3101b971-1044-4816-a7ac-9ded2e028079
    externalMetadata:
      listing:
        blurb: MySQL service for application development and testing
        imageUrl: null
      provider:
        name: null
    externalName: p-mysql
    planUpdatable: false
    tags:
    - mysql
    - relational
  status:
    removedFromBrokerCatalog: false
```

## Step 5 - Create namespace for service instance isolation
In kubernetes, `namespaces` are used to isolate different users' resources from others. For service broker, users can create service instances in their own namespace, so that others can not touch it without authorization of that namespace.

```console
[root@~]# kubectl create namespace test-ns
```

## Step 6 - Create Mysql Service Instance

```console
[root@~]# kubectl create -f demo/standaloneMySQLSI.yaml
```
Note: Assign service instance in specific namespace by updating the yaml file. Otherwise, the instance will be exposed to default namespace.

Check the instance status after creataion.

```console
[root@~]# kubectl get serviceinstance standalone-mysql-instance -n test-ns -o yaml

Sample output looks like:

apiVersion: servicecatalog.k8s.io/v1beta1
kind: ServiceInstance
metadata:
  creationTimestamp: 2017-11-06T09:51:36Z
  finalizers:
  - kubernetes-incubator/service-catalog
  generation: 1
  name: standalone-mysql-instance
  namespace: test-ns
  resourceVersion: "68"
  selfLink: /apis/servicecatalog.k8s.io/v1beta1/namespaces/test-ns/serviceinstances/standalone-mysql-instance
  uid: 1442ca94-c2d8-11e7-b157-0a58ac100508
spec:
  clusterServiceClassExternalName: p-mysql
  clusterServiceClassRef:
    name: 3101b971-1044-4816-a7ac-9ded2e028079
  clusterServicePlanExternalName: 5mb
  clusterServicePlanRef:
    name: 2451fa22-df16-4c10-ba6e-1f682d3dcdc9
  externalID: f9ecf74e-0712-4f04-a4d5-d84eb6de0ea5
  parameters:
    credentials:
      param-1: value-1
  updateRequests: 0
status:
  asyncOpInProgress: false
  conditions:
  - lastTransitionTime: 2017-11-06T09:51:36Z
    message: The instance was provisioned successfully
    reason: ProvisionedSuccessfully
    status: "True"
    type: Ready
  deprovisionStatus: Required
  externalProperties:
    clusterServicePlanExternalName: 5mb
    parameterChecksum: e6f89e73eff47fec7606886dbe0ffe5d61a7ee529af03b7fc17041ae27d7580d
    parameters:
      credentials:
        param-1: value-1
  orphanMitigationInProgress: false
  reconciledGeneration: 1
```

Create Instance will send PUT request to service broker server and broker server will handle to create the database with cf name perfix in mysql server.

## Step 7 - Binding Service Instance

Then Create a mysql service binding, which is used by application to connect to mysql service instance .
Note: 
1. Like service instance, service binding can also be assigned in specific namespace by updating its yaml file. Otherwise, the binding will be exposed to default namespace.
2. To simplify the demo, update mysql password validation policy to low level to accept password only with length validation. Connect to mysql, and execute 
```console
mysql> set global validate_password_policy=0;
```

```console
[root@~]# kubectl create -f demo/standaloneMySQLSBinding.yaml
```

Check the binding status

```console
[root@~]# kubectl get servicebindings -n test-ns

Sample output looks like:
NAME                        AGE
standalone-mysql-binding    1d
```

```console
[root@~]# kubectl get servicebinding standalone-mysql-binding8 -n test-ns -o yaml

Sample output looks like:
apiVersion: servicecatalog.k8s.io/v1beta1
kind: ServiceBinding
metadata:
  creationTimestamp: 2017-11-07T09:21:13Z
  finalizers:
  - kubernetes-incubator/service-catalog
  generation: 1
  name: standalone-mysql-binding
  namespace: test-ns
  resourceVersion: "414"
  selfLink: /apis/servicecatalog.k8s.io/v1beta1/namespaces/test-ns/servicebindings/standalone-mysql-binding
  uid: ffefb63b-c39c-11e7-9323-0a58ac100508
spec:
  externalID: 92e81144-8b24-4760-8863-797155a0368a
  instanceRef:
    name: standalone-mysql-instance
  secretName: mysql-secret
status:
  conditions:
  - lastTransitionTime: 2017-11-07T09:21:13Z
    message: Injected bind result
    reason: InjectedBindResult
    status: "True"
    type: Ready
  externalProperties: {}
  orphanMitigationInProgress: false
  reconciledGeneration: 1
```

Bind Instance will send PUT request to broker server and broker server will create the username and password and grant the privileged for the db user and return the credentials to service catalog which used to create the kubernetes secret.

So After the binging success, the kubernetes secret will be created.

## Step 8 - Check the generated secret

After the binding success, the kubernetes secret will be created under the same namespaces as service binding. Secret is the more eligent and secure way to transfer credential information. Please refer to kubernetes doc to learn how to config and use Secret.

```console
[root@~]# kubectl get secret -n test-ns

Sample output looks like:

NAME                  TYPE                                  DATA      AGE
mysql-secret          Opaque                                4         1d

[root@~]# kubectl get secret mysql-secret -n test-ns -o yaml

Sample output looks like:

apiVersion: v1
data:
  database: Y2ZfZjllY2Y3NGVfMDcxMl80ZjA0X2E0ZDVfZDg0ZWI2ZGUwZWE1
  password: ZjQxZTBjYzktYzI3Mi00NDg1LWJiNjEtNmEzYzEzODk2ZDc3
  uri: bXlzcWw6Ly9sb2NhbGhvc3QvdGVzdA==
  username: N2E0ODY2NGQ0OWM5ZWQ5NQ==
kind: Secret
metadata:
  creationTimestamp: 2017-11-07T09:21:13Z
  name: mysql-secret
  namespace: test-ns
  ownerReferences:
  - apiVersion: servicecatalog.k8s.io/v1beta1
    blockOwnerDeletion: true
    controller: true
    kind: ServiceBinding
    name: standalone-mysql-binding
    uid: ffefb63b-c39c-11e7-9323-0a58ac100508
  resourceVersion: "1552248"
  selfLink: /api/v1/namespaces/test-ns/secrets/mysql-secret8
  uid: 0034bfcb-c39d-11e7-b848-00163e0abefa
type: Opaque

```

## Step 8 - Using the Secret

Prepare test pod yaml file like `demo/usemysql.yaml`:

```console
{
 "apiVersion": "v1",
 "kind": "Pod",
  "metadata": {
    "name": "usemysqlpod",
    "namespace": "test-ns"
  },
  "spec": {
    "hostNetwork": true,
    "containers": [{
      "name": "usemysqlpod",
      "image": "mysql:5.7",
      "volumeMounts": [{
        "name": "foo",
        "mountPath": "/etc/foo",
        "readOnly": true
      }],
      "command": ["/bin/sh"],
      "args": ["-c", "while true; do sleep 100; done"]
    }],
    "volumes": [{
      "name": "foo",
      "secret": {
        "secretName": "mysql-secret"
      }
    }]
  }
}
```

Create the pod resource

```console
[root@~]# kubectl create -f demo/usemysql.yaml
[root@~]# kubectl exec -it usemysqlpod
[root@~]# kubectl get pods

Sample output looks like:

NAME      READY     STATUS    RESTARTS   AGE
usemysqlpod     1/1       Running   0          1m

[root@~]# kubectl exec -it usemysqlpod bash
root@usemysqlpod:/# cat /etc/foo/database
cf_93a4eef9_5893_4198_a822_44f4eac0ae3f
root@usemysqlpod:/# cat /etc/foo/username
a9d8618ed37a38ea
root@usemysqlpod:/# cat /etc/foo/password
07c5e9a5-bd12-4bac-b6be-6f651903ba5f
```

Then use mysql client to try to connect

```console
mysql -ua9d8618ed37a38ea -p07c5e9a5-bd12-4bac-b6be-6f651903ba5f

mysql> show databases;
+-----------------------------------------+
| Database                                |
+-----------------------------------------+
| information_schema                      |
| cf_93a4eef9_5893_4198_a822_44f4eac0ae3f |
+-----------------------------------------+
2 rows in set (0.00 sec)
```

The connect success and can show my databases which created by broker server.


