FROM quay.io/strimzi/kafka:0.49.1-kafka-4.0.0
USER root:root
RUN mkdir -p /opt/kafka/plugins/camel-mqtt
RUN curl -L https://repo1.maven.org/maven2/org/apache/camel/kafkaconnector/camel-mqtt-source-kafka-connector/3.20.3/camel-mqtt-source-kafka-connector-3.20.3-package.tar.gz | tar xz -C /opt/kafka/plugins/camel-mqtt
RUN rm -f /opt/kafka/plugins/camel-mqtt/kafka-clients-*.jar \
        /opt/kafka/plugins/camel-mqtt/connect-api-*.jar \
        /opt/kafka/plugins/camel-mqtt/connect-json-*.jar \
        /opt/kafka/plugins/camel-mqtt/connect-transforms-*.jar \
        /opt/kafka/plugins/camel-mqtt/lz4-java-*.jar \
        /opt/kafka/plugins/camel-mqtt/snappy-java-*.jar \
        /opt/kafka/plugins/camel-mqtt/slf4j-api-*.jar
USER 1001
