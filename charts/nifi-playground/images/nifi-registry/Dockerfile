FROM apache/nifi-registry:1.23.2

USER root
# Create custom lib directory
RUN mkdir -p /opt/nifi-registry/nifi-registry-current/lib/custom

# Copy the downloaded driver
COPY postgresql-jdbc.jar /opt/nifi-registry/nifi-registry-current/lib/custom/postgresql-jdbc.jar

# Fix permissions
RUN chown -R nifi:nifi /opt/nifi-registry/nifi-registry-current/lib/custom && \
    chmod 644 /opt/nifi-registry/nifi-registry-current/lib/custom/postgresql-jdbc.jar

# Copy startup script
COPY start.sh /opt/nifi-registry/scripts/start.sh
RUN chmod +x /opt/nifi-registry/scripts/start.sh

USER nifi
CMD ["/opt/nifi-registry/scripts/start.sh"]
