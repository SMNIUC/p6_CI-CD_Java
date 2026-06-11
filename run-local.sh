#!/usr/bin/env bash
#
# run-local.sh — Launch the application locally with the right environment.
#
# It loads the database credentials from the local ".env" file (creating it from
# ".env.example" on first run), verifies the required variables are set, then
# starts the app with `./gradlew bootRun`. Any extra arguments are forwarded to
# Gradle (e.g. `./run-local.sh --args='--server.port=9090'`).

set -uo pipefail

# Always operate from the directory this script lives in (the project root).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE=".env"
ENV_TEMPLATE=".env.example"
REQUIRED_VARS=(SPRING_DATASOURCE_USERNAME SPRING_DATASOURCE_PASSWORD)

log()  { printf '\033[1;34m[run-local]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[run-local]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[run-local]\033[0m %s\n' "$*" >&2; }

# ------------------------------------------------------------------
# 1. Verify required dependencies
# ------------------------------------------------------------------
if [[ ! -x "./gradlew" ]]; then
    if [[ -f "./gradlew" ]]; then
        warn "./gradlew is not executable — fixing permissions."
        chmod +x ./gradlew
    else
        err "Gradle wrapper (./gradlew) not found in $SCRIPT_DIR."
        exit 1
    fi
fi

if ! command -v java >/dev/null 2>&1; then
    err "Java is not installed or not on PATH. JDK 21 is required (see README)."
    exit 1
fi

# ------------------------------------------------------------------
# 2. Make sure a .env file exists
# ------------------------------------------------------------------
if [[ ! -f "$ENV_FILE" ]]; then
    if [[ -f "$ENV_TEMPLATE" ]]; then
        cp "$ENV_TEMPLATE" "$ENV_FILE"
        err "No $ENV_FILE found — created one from $ENV_TEMPLATE."
        err "Edit $ENV_FILE with your local database credentials, then re-run this script."
        exit 1
    else
        err "Neither $ENV_FILE nor $ENV_TEMPLATE found — cannot determine DB credentials."
        exit 1
    fi
fi

# ------------------------------------------------------------------
# 3. Load the environment variables from .env
# ------------------------------------------------------------------
log "Loading environment from $ENV_FILE"
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# Verify the required variables are now set (and not left at the template default).
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        err "Required variable '$var' is not set in $ENV_FILE."
        exit 1
    fi
done
if [[ "${SPRING_DATASOURCE_PASSWORD}" == "changeme" ]]; then
    warn "SPRING_DATASOURCE_PASSWORD is still the template value 'changeme' — update $ENV_FILE with your real password."
fi

# ------------------------------------------------------------------
# 4. Launch the application
# ------------------------------------------------------------------
log "Starting the application: ./gradlew bootRun"
exec ./gradlew bootRun "$@"
