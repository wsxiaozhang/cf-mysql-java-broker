From java:openjdk-8-alpine

WORKDIR  /workspace 
ADD      pre-built/cf-mysql-java-broker-0.1.0.jar .
CMD      java -jar cf-mysql-java-broker-0.1.0.jar
