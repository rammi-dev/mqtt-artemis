#!/bin/sh -e

# Define variables
NIFI_REGISTRY_HOME="/opt/nifi-registry/nifi-registry-current"
PROPS_FILE="${NIFI_REGISTRY_HOME}/conf/nifi-registry.properties"

echo "Configuring NiFi Registry..."

# Function to replace properties
prop_replace () {
  target_file=${3:-${PROPS_FILE}}
  echo "replacing target file ${target_file}"
  sed -i -e "s|^$1=.*$|$1=$2|"  "${target_file}"
}

# Copy template if needed (though we mount configmap, so we might skip this or cp from configmap)
# In our case, we mount configmap to /opt/nifi-registry/nifi-registry-current/conf/templates/nifi-registry.properties
# so we should copy it to the destinations.
if [ -f "${NIFI_REGISTRY_HOME}/conf/templates/nifi-registry.properties" ]; then
    echo "Copying template properties file..."
    cp "${NIFI_REGISTRY_HOME}/conf/templates/nifi-registry.properties" "${PROPS_FILE}"
fi

# Inject Database Credentials
if [ -n "${NIFI_REGISTRY_DB_USERNAME}" ]; then
    echo "Injecting DB Username..."
    sed -i "s|DB_USER_PLACEHOLDER|${NIFI_REGISTRY_DB_USERNAME}|g" "${PROPS_FILE}"
fi

if [ -n "${NIFI_REGISTRY_DB_PASSWORD}" ]; then
    echo "Injecting DB Password..."
    sed -i "s|DB_PASS_PLACEHOLDER|${NIFI_REGISTRY_DB_PASSWORD}|g" "${PROPS_FILE}"
fi

# Ensure internal binding settings are correct (sometimes issues if bound to localhost)
prop_replace 'nifi.registry.web.http.host' ''

echo "--- Configuration Complete ---"
echo "--- Dumping nifi-registry.properties ---"
cat "${PROPS_FILE}"
echo "----------------------------------------"

# Ensure log directory exists
mkdir -p "${NIFI_REGISTRY_HOME}/logs"
touch "${NIFI_REGISTRY_HOME}/logs/nifi-registry-app.log"

# Start tailing logs in background
tail -F "${NIFI_REGISTRY_HOME}/logs/nifi-registry-app.log" &

# Start Registry in background to capture PID
echo "Starting NiFi Registry..."
"${NIFI_REGISTRY_HOME}/bin/nifi-registry.sh" run &
nifi_registry_pid="$!"

# Trap signals for graceful shutdown
trap "echo 'Received trapped signal, beginning shutdown...'; ${NIFI_REGISTRY_HOME}/bin/nifi-registry.sh stop; exit 0;" KILL TERM HUP INT EXIT

echo "NiFi-Registry running with PID ${nifi_registry_pid}"
wait ${nifi_registry_pid}
