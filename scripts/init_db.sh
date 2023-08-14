#!/usr/bin/env bash
set -x
set -eo pipefail

if ! [ -x "$(command -v docker)" ]; then
  echo 'Error: docker is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v psql)" ]; then
  echo 'Error: psql is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v sqlx)" ]; then
  echo 'Error: sqlx is not installed.' >&2
  exit 1
fi

# Check if a custom user has been set, otherwise default to `postgres`
DB_USER=${POSTGRES_USER:=postgres}
# Check if a custom password has been set, otherwise default to `password`
DB_PASSWORD="${POSTGRES_PASSWORD:=password}"
# Check if a custom database name has been ste, otherwise default to `newsletter`
DB_NAME="${POSTGRES_DB:=newsletter}"
# Check if a custom port has been set, otherwise default to `5432`
DB_PORT="${POSTGRES_PORT:=5432}"
# Check if a custom host has been set, otherwise default to `localhost`
DB_HOST="${POSTGRES_HOST:=localhost}"


# Allow to skip Docker if a dockerized Postgres database is already running
if [[ -z "${SKIP_DOCKER}" ]]
then
    docker run \
      -e POSTGRES_USER=${DB_USER} \
      -e POSTGRES_PASSWORD=${DB_PASSWORD} \
      -e POSTGRES_DB=${DB_NAME} \
      -e POSTGRES_PORT=${DB_PORT} \
      -e POSTGRES_HOST=${DB_HOST} \
      -p "${DB_PORT}":5432 \
      -d postgres \
      postgres -N 1000
fi

# Keep pinging Postgres until it's ready to accept commands
export PGPASSWORD="${DB_PASSWORD}"
until psql -h "${DB_HOST}" -U "${DB_USER}" -p "${DB_PORT}" -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
export DATABASE_URL
sqlx database create
sqlx migrate run

>&2 echo "Postgres has been migrated, ready to go!"
