This is a sample chart of running mysql-java-broker server in Kubernetes cluster.
Just follow the common way to install it via helm install. For instance, on one Kubernetes 
master node, copy this chart artifacts as below.
```
[root@localhost ~]# git clone https://github.com/wsxiaozhang/cf-mysql-java-broker.git
[root@localhost ~]# cd cf-mysql-java-broker/charts/mysql-java-broker
[root@localhost ~]# helm install --name mysql-java-broker --namespace mysql-java-broker .
```
After installation, confirm the broker server service is ready to access.

```
[root@localhost ~]# kubectl get svc -n mysql-java-broker -o yaml
```
the sample output looks like:
```
apiVersion: v1
items:
- apiVersion: v1
  kind: Service
  metadata:
    creationTimestamp: 2017-11-10T11:01:59Z
    labels:
      chart: mysql-java-broker-0.0.1
    name: mysql-java-broker-mysql-java-broker
    namespace: mysql-java-broker
    resourceVersion: "2150066"
    selfLink: /api/v1/namespaces/mysql-java-broker/services/mysql-java-broker-mysql-java-broker
    uid: 9321263c-c606-11e7-aefa-00163e0ab996
  spec:
    clusterIP: 172.19.4.37
    externalTrafficPolicy: Cluster
    ports:
    - name: mysql-java-broker
      nodePort: 31148
      port: 80
      protocol: TCP
      targetPort: 9000
    selector:
      app: mysql-java-broker-mysql-java-broker
    sessionAffinity: None
    type: NodePort
  status:
    loadBalancer: {}
kind: List
metadata:
  resourceVersion: ""
  selfLink: ""
  ```
