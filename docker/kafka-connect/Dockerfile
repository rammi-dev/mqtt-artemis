FROM quay.io/strimzi/kafka:0.49.1-kafka-4.0.0
USER root:root
# Clean any existing plugins and create fresh directory
RUN rm -rf /opt/kafka/plugins/* && mkdir -p /opt/kafka/plugins/stream-reactor
# Download Lenses Stream Reactor 11.1.0 MQTT connector (compatible with Kafka 4.0/4.1)
RUN curl -L https://github.com/lensesio/stream-reactor/releases/download/11.1.0/kafka-connect-mqtt-11.1.0-4.1.0-all.jar -o /opt/kafka/plugins/stream-reactor/kafka-connect-mqtt-11.1.0-4.1.0-all.jar
USER 1001
