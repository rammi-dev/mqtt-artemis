FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir \
    dagster \
    dagster-postgres \
    dagster-k8s \
    dagster-webserver \
    clickhouse-connect \
    redis \
    pandas

# Copy pipeline code
COPY pipelines/ /app/pipelines/

# Set Python path
ENV PYTHONPATH=/app

# Expose gRPC port for Dagster
EXPOSE 3030

# Default command for user code deployment
CMD ["dagster", "api", "grpc", "-h", "0.0.0.0", "-p", "3030", "-m", "pipelines"]
