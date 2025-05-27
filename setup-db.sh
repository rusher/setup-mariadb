#!/bin/bash
CONTAINER_RUNTIME=""
CONTAINER_ARGS=""
CONTAINER_IMAGE=""
REGISTRY_PREFIX=""

###############################################################################
echo "::group::🔍 Verifying inputs"

# CONTAINER_RUNTIME
# If the setup container runtime is set, verify the runtime is available
if [ -n "${SETUP_CONTAINER_RUNTIME}" ]; then
    # Container runtime exists
    if type "${SETUP_CONTAINER_RUNTIME}" > /dev/null; then
        CONTAINER_RUNTIME="${SETUP_CONTAINER_RUNTIME}"
        echo "✅ container runtime set to ${CONTAINER_RUNTIME}"
    fi
fi
# If container runtime is empty (either doesn't exist, or wasn't passed on), find default
if [ -z "${CONTAINER_RUNTIME}" ]; then
  if type podman > /dev/null; then
      CONTAINER_RUNTIME="podman"
      echo "☑️️ container runtime set to ${CONTAINER_RUNTIME} (default)"
  elif type docker > /dev/null; then
      CONTAINER_RUNTIME="docker"
      echo "☑️️ container runtime set to ${CONTAINER_RUNTIME} (default)"
  else
      echo "❌ container runtime not available."
      exit 1;
  fi
fi

# TAG
if [ -z "${SETUP_TAG}" ]; then
    SETUP_TAG="latest"
fi

if [ -z "${SETUP_REGISTRY}" ]; then
    SETUP_REGISTRY="docker.io/mariadb"
    REGISTRY_PREFIX="docker.io"
else
  if [ "${SETUP_REGISTRY}" eq "docker.io/mariadb"] || [ "${SETUP_REGISTRY}" eq "quay.io/mariadb-foundation/mariadb-devel"]  || [ "${SETUP_REGISTRY}" eq "docker.mariadb.com/enterprise-server"]; then
      echo "❌ wrong repository value ${SETUP_REGISTRY}. permit values are 'docker.io/mariadb', 'quay.io/mariadb-foundation/mariadb-devel' or 'docker.mariadb.com/enterprise-server'."
      exit 1;
  fi
  if [ "${SETUP_REGISTRY}" eq "docker.io/mariadb"]; then
      REGISTRY_PREFIX="docker.io"
  else
    if [ "${SETUP_REGISTRY}" eq "quay.io/mariadb-foundation/mariadb-devel"]; then
      REGISTRY_PREFIX="quay.io"
    else
      REGISTRY_PREFIX="docker.mariadb.com"
    fi
  fi
fi

CONTAINER_IMAGE="${SETUP_REGISTRY}:${SETUP_TAG}"
echo "✅ container image set to ${CONTAINER_IMAGE}"

# PORT
if [ -z "${SETUP_PORT}" ]; then
  SETUP_PORT=3306
fi
echo "✅ port set to ${SETUP_PORT}"

CONTAINER_ARGS="${CONTAINER_ARGS} -p 3306:${SETUP_PORT}"
CONTAINER_ARGS="${CONTAINER_ARGS} --name mariadb"

# PASSWORD
if [ -n "${SETUP_ROOT_PASSWORD}" ]; then
    CONTAINER_ARGS="${CONTAINER_ARGS} -e MARIADB_ROOT_PASSWORD=${SETUP_ROOT_PASSWORD}"
    echo "✅ MARIADB_ROOT_PASSWORD explicitly set"
else
  if [ -n "${SETUP_ALLOW_EMPTY_ROOT_PASSWORD}"] && ( [ "${SETUP_ALLOW_EMPTY_ROOT_PASSWORD}" eq "1" ]; || [ "${SETUP_ALLOW_EMPTY_ROOT_PASSWORD}" eq "yes" ]); then
    CONTAINER_ARGS="${CONTAINER_ARGS} -e MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=1"
  else
    CONTAINER_ARGS="${CONTAINER_ARGS} -e MARIADB_RANDOM_ROOT_PASSWORD=1"
    echo "⚠️ root password will be randomly generated"
  fi
fi

# DATABASE
if [ -n "${SETUP_DATABASE}" ]; then
    echo "✅ database name set to ${SETUP_DATABASE}"
    CONTAINER_ARGS="${CONTAINER_ARGS} -e MARIADB_DATABASE=${SETUP_DATABASE}"
fi

# USER
if [ -n "${SETUP_USER}" ]; then
    echo "✅ MARIADB_USER explicitly set"
    CONTAINER_ARGS="${CONTAINER_ARGS} -e MARIADB_USER=${SETUP_USER}"
fi

# PASSWORD
if [ -n "${SETUP_PASSWORD}" ]; then
    echo "✅ MARIADB_PASSWORD explicitly set"
    CONTAINER_ARGS="${CONTAINER_ARGS} -e MARIADB_PASSWORD=${SETUP_PASSWORD}"
fi

# SETUP_SCRIPTS
if [ -n "${SETUP_CONF_SCRIPT_FOLDER}" ]; then
    echo "✅ setup scripts from ${SETUP_CONF_SCRIPT_FOLDER}"
    CONTAINER_ARGS="${CONTAINER_ARGS} -v ${SETUP_SETUP_SCRIPTS}:/etc/mysql/conf.d:ro"
fi

# STARTUP_SCRIPTS
if [ -n "${SETUP_INIT_SCRIPT_FOLDER}" ]; then
    echo "✅ startup scripts from ${SETUP_INIT_SCRIPT_FOLDER}"
    CONTAINER_ARGS="${CONTAINER_ARGS} -v ${SETUP_INIT_SCRIPT_FOLDER}:/docker-entrypoint-initdb.d"
fi

echo "::endgroup::"

###############################################################################

if [ -n "${SETUP_REGISTRY_USER}" ] && [ -n "${SETUP_REGISTRY_PASSWORD}" ]; then
  echo "✅ registry information set"
  CMD="${CONTAINER_RUNTIME} login ${REGISTRY_PREFIX} --username ${SETUP_ENTERPRISE_USER} --password ${SETUP_ENTERPRISE_TOKEN}"
  eval "${CMD}"
  echo "✅ connected to ${REGISTRY_PREFIX}"
else
  if [ "${SETUP_REGISTRY}" eq eq "docker.mariadb.com/enterprise-server"]; then
      echo "❌ registry was not set"
      exit 1;
  fi
fi



###############################################################################
echo "::group::🐳 Running Container"
CMD="${CONTAINER_RUNTIME} run -d ${CONTAINER_ARGS} ${CONTAINER_IMAGE}"
echo "${CMD}"
# Run Docker container
eval "${CMD}"
echo "::endgroup::"
###############################################################################

###############################################################################
echo "::group::⏰ Waiting for database to be ready"
DB_IS_UP=""
EXIT_VALUE=0

for ((COUNTER=1; COUNTER <= 60; COUNTER++))
do
    echo "  - try #${COUNTER} of ${HEALTH_MAX_RETRIES}"
    sleep 1
    DB_IS_UP=$("${CONTAINER_RUNTIME}" exec mariadb healthcheck.sh && echo "yes" || echo "no")
    if [ "${DB_IS_UP}" = "yes" ]; then
        break
    fi
done

echo "::endgroup::"
# Start a new group so that database readiness or failure is visible in actions.

if [ "${DB_IS_UP}" = "yes" ]; then
    echo "::group::✅ Database is ready!"
else
    echo "::group::❌ Database failed to start on time."
    echo "🔎 Container logs:"
    "${CONTAINER_RUNTIME}" logs mariadb
    EXIT_VALUE=1
fi

echo "::endgroup::"
###############################################################################
exit ${EXIT_VALUE}
