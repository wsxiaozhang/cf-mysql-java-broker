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

# Service Catalog in CFC

This document outlines the basic features of the service catalog by walking
through a short demo.

## Step 0 - Prerequisites

### environment requirement

1. kubernetes 1.6.1 +


## Step 1 - Installing the Service Catalog System

Get the tar file [service-catalog](https://github.com/hchenxa/daily_work/blob/master/kubernetes/service-catalog/catalog-0.0.1.tgz) and use helm to deploy the service catalog system

```console
helm install catalog-0.0.1.tgz --name catalog
```

And the catalog will be created as kubernetes deployment.

```console
root@hchenk8s1:~# kc get deployment --all-namespaces

NAMESPACE     NAME                                 DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
kube-system   catalog-catalog-apiserver            1         1         1            1           1d
kube-system   catalog-catalog-controller-manager   1         1         1            1           1d
```

And also the deployment will be expose as the service
```console
root@hchenk8s1:~# kc get service --all-namespaces | grep cata
kube-system   catalog-catalog-apiserver   10.0.0.149   <nodes>       80:30080/TCP,443:30443/TCP       1d
```

## Step 2 - Setup MySQL broker server
Environment requirement: Need java installed.

and the source code was here: https://github.com/hchenxa/cf-mysql-java-broker

1.First setup the mysql server.

```console
apt install mysql-server
```

comment the bind-address in mysql config file:

```console
root@hchenk8s7:~# cat /etc/mysql/mysql.conf.d/mysqld.cnf | grep bind

#bind-address		= 127.0.0.1
```

and the mysql root password must be **root**

And need to create a database named **test** by CREATE DATABASE test;


2.Startup the broker server

Get the JAR file [mysql-broker](https://github.com/hchenxa/daily_work/blob/master/kubernetes/service-catalog/cf-mysql-java-broker-0.1.0.jar)

and execute

```console
java -jar cf-mysql-java-broker-0.1.0.jar
```

The default port was 9000, we can use http://<host_ip>:9000/v2/catalog to check if the server was ready.

## Step 3 - Create broker resource

First config the kube-config to connect service catalog api

```console
kubectl config set-cluster service-catalog --server=http://$SVC_CAT_API_SERVER_IP:30080
kubectl config set-context service-catalog --cluster=service-catalog
```

SVC\_CAT\_API\_SERVER\_IP: The IP Address of the catalog-api service if you were using ClusterIP or the IP address of the Node if you were using NodePort


Then create the service broker:

```console
kubectl --context=service-catalog create -f mysql-broker.yaml

```

Check the broker status


```console
root@hchenk8s1:~# kubectl --context=service-catalog get broker -o yaml
apiVersion: servicecatalog.k8s.io/v1alpha1
kind: Broker
metadata:
  creationTimestamp: 2017-04-12T05:12:31Z
  finalizers:
  - kubernetes
  name: mysql-broker
  resourceVersion: "424"
  selfLink: /apis/servicecatalog.k8s.io/v1alpha1/brokersmysql-broker
  uid: a14c47cb-1f3e-11e7-a0b9-b6ef720f6067
spec:
  url: http://9.111.254.218:9000
status:
  conditions:
  - message: Successfully fetched catalog from broker.
    reason: FetchedCatalog
    status: "True"
    type: Ready
```

After broker resource created, the connection between service catalog and broker server will be created.


## Step 4 - Check the catalog

Check the service catalog:

```console
root@hchenk8s1:~# kubectl --context=service-catalog get serviceclass -o yaml
apiVersion: servicecatalog.k8s.io/v1alpha1
bindable: false
brokerName: mysql-broker
description: MySQL service for application development and testing
kind: ServiceClass
metadata:
  creationTimestamp: 2017-04-12T05:12:31Z
  name: p-mysql
  resourceVersion: "35"
  selfLink: /apis/servicecatalog.k8s.io/v1alpha1/serviceclassesp-mysql
  uid: a17649ae-1f3e-11e7-a0b9-b6ef720f6067
osbGuid: 3101b971-1044-4816-a7ac-9ded2e028079
osbMetadata:
  listing:
    blurb: MySQL service for application development and testing
    imageUrl: null
  provider:
    name: null
osbTags:
- mysql
- relational
planUpdatable: false
plans:
- description: Shared MySQL Server, 5mb persistent disk, 40 max concurrent connections
  name: 5mb
  osbFree: false
  osbGuid: 2451fa22-df16-4c10-ba6e-1f682d3dcdc9
  osbMetadata:
    bullets:
    - content: Shared MySQL server
    - content: 5 MB storage
    - content: 40 concurrent connections
    cost: 0
```

## Step 5 - Create Instance

```console
kubectl --context=service-catalog create -f mysql-instance.yaml
```

And Check the instance status after creataion.

```console
root@hchenk8s1:~# kubeca get instance --namespace=hchentest
NAME             KIND
mysql-instance   Instance.v1alpha1.servicecatalog.k8s.io
root@hchenk8s1:~# kubeca get instance --namespace=hchentest -o yaml
apiVersion: v1
items:
- apiVersion: servicecatalog.k8s.io/v1alpha1
  kind: Instance
  metadata:
    creationTimestamp: 2017-04-07T14:48:29Z
    finalizers:
    - kubernetes
    name: mysql-instance
    namespace: hchentest
    resourceVersion: "408"
    selfLink: /apis/servicecatalog.k8s.io/v1alpha1/namespaces/hchentest/instances/mysql-instance
    uid: 43a08214-1ba1-11e7-9917-4a6adf82f80b
  spec:
    checksum: 6e79e8643d9382239a666b44b9948e65789b72e0dc12ad3fc23cfc47b6cfc425
    osbGuid: 2df17f6c-6b5a-44bb-8492-64899c7b2541
    planName: 5mb
    serviceClassName: p-mysql
  status:
    conditions:
    - message: The instance was provisioned successfully
      reason: ProvisionedSuccessfully
      status: "True"
      type: Ready
kind: List
metadata: {}
resourceVersion: ""
selfLink: ""
```

Create Instance will send PUT request to broker server and broker server will handle to create the database with cf name perfix in mysql db

## Step 6 - Binding Instance

Then Create the mysql binding.

```console
kubectl --context=service-catalog create -f mysql-binding.yaml
```

Check the binding status

```console
root@hchenk8s1:~# kubeca get binding --namespace=hchentest
NAME            KIND
mysql-binding   Binding.v1alpha1.servicecatalog.k8s.io
root@hchenk8s1:~# kubeca get binding --namespace=hchentest -o yaml
apiVersion: v1
items:
- apiVersion: servicecatalog.k8s.io/v1alpha1
  kind: Binding
  metadata:
    creationTimestamp: 2017-04-07T09:56:37Z
    deletionGracePeriodSeconds: 0
    deletionTimestamp: 2017-04-07T10:14:02Z
    finalizers:
    - kubernetes
    name: mysql-binding
    namespace: hchentest
    resourceVersion: "409"
    selfLink: /apis/servicecatalog.k8s.io/v1alpha1/namespaces/hchentest/bindings/mysql-binding
    uid: 7dd163e1-1b78-11e7-9917-4a6adf82f80b
  spec:
    checksum: b6119b55a57267347ab7dec8cadf86aee68a1261ed381e8c6b75f1790ff671a1
    instanceRef:
      name: mysql-instance
    osbGuid: 078a417e-4492-4091-b9c4-f41d0aeffd54
    secretName: mysql-secret
  status:
    conditions:
    - message: Injected bind result
      reason: InjectedBindResult
      status: "True"
      type: Readykind: List
metadata: {}
resourceVersion: ""
selfLink: ""
```

Bind Instance will send PUT request to broker server and broker server will create the username and password and grant the privileged for the db user and return the credentials to service catalog which used to create the kubernetes secret.

So After the binging success, the kubernetes secret will be created.

## Step 7 - Check the secret

After the binding success, the kubernetes secret will be created under namespaces.

```console
root@hchenk8s1:~# kubectl get secret -o yaml mysql-secret
apiVersion: v1
data:
  database: Y2ZfNDBkYTdjMjRfMjc5NV80YmI3X2FhZWVfNDdmNzRkNTY0ZjM2
  password: ZjFmZjE1NDAtZTNkNi00OWQ3LTk5OTctODgwMzQyOTc0YWU1
  username: MjRjNGMzMjdlNWE3NGYwZA==
kind: Secret
metadata:
  creationTimestamp: 2017-04-13T01:54:31Z
  name: mysql-secret
  namespace: default
  resourceVersion: "784356"
  selfLink: /api/v1/namespaces/default/secrets/mysql-secret
  uid: 22cfff41-1fec-11e7-9b2b-3aab550ec08b
type: Opaque
```

## Step 8 - Using the Secret

Prepare test pod yaml file:

```console
{
 "apiVersion": "v1",
 "kind": "Pod",
  "metadata": {
    "name": "mypod",
    "namespace": "default"
  },
  "spec": {
    "hostNetworl": true,
    "containers": [{
      "name": "mypod",
      "image": "mysql:5.6",
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
kubectl exec -it mypod
root@hchenk8s1:~# kubectl get pods
NAME      READY     STATUS    RESTARTS   AGE
mypod     1/1       Running   0          1m
root@hchenk8s1:~# kubectl exec -it mypod bash
root@mypod:/# cat /etc/foo/database
cf_93a4eef9_5893_4198_a822_44f4eac0ae3f
root@mypod:/# cat /etc/foo/username
a9d8618ed37a38ea
root@mypod:/# cat /etc/foo/password
07c5e9a5-bd12-4bac-b6be-6f651903ba5f
```

Then use mysql client to try to connect

```console
mysql -ua9d8618ed37a38ea -p07c5e9a5-bd12-4bac-b6be-6f651903ba5f -Dcf_93a4eef9_5893_4198_a822_44f4eac0ae3f -h9.111.254.218
Warning: Using a password on the command line interface can be insecure.
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 4
Server version: 5.7.11-0ubuntu6 (Ubuntu)

Copyright (c) 2000, 2017, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

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


