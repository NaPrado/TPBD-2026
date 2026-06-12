#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env.local"

if [[ ! -f "$ROOT_DIR/funciones.sql" ]]; then
  echo "No existe funciones.sql" >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "No existe .env.local" >&2
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

export PGPASSWORD="$POSTGRES_PASSWORD"

port_is_listening() {
  ss -ltn "( sport = :$1 )" 2>/dev/null | grep -q ":$1"
}

find_free_port() {
  local port
  for port in {55432..55532}; do
    if ! port_is_listening "$port"; then
      printf '%s\n' "$port"
      return 0
    fi
  done
  return 1
}

POSTGRES_PORT="${POSTGRES_PORT:-5433}"
PSQL=(psql -h localhost -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1)

if ! "${PSQL[@]}" -qAt -c "SELECT 1" >/dev/null 2>&1 && port_is_listening "$POSTGRES_PORT"; then
  POSTGRES_PORT="$(find_free_port)"
  export POSTGRES_PORT
  PSQL=(psql -h localhost -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1)
  echo "Puerto 5433 ocupado; usando POSTGRES_PORT=$POSTGRES_PORT"
else
  export POSTGRES_PORT
fi

COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.yml")

"${COMPOSE[@]}" up -d db

echo "Esperando a PostgreSQL..."
for _ in {1..60}; do
  if "${PSQL[@]}" -qAt -c "SELECT 1" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

"${PSQL[@]}" -qAt -c "SELECT 1" >/dev/null

echo "Creando esquema desde funciones.sql"
"${PSQL[@]}" -f "$ROOT_DIR/funciones.sql"

echo "Importando subasta.csv"
"${PSQL[@]}" -c "\\copy subasta(id, descripcion, categoria, email_vendedor, fecha_inicio, fecha_cierre, precio_base, incremento_min) FROM '$ROOT_DIR/subasta.csv' WITH (FORMAT csv, HEADER true)"

echo "Importando oferta.csv"
"${PSQL[@]}" -c "\\copy oferta(id_subasta, email_usuario, fecha_hora, monto) FROM '$ROOT_DIR/oferta.csv' WITH (FORMAT csv, HEADER true)"

for test_file in "$ROOT_DIR"/testing/[0-9][0-9]_*.sql; do
  echo "Ejecutando $(basename "$test_file")"
  "${PSQL[@]}" -f "$test_file"
done

echo "Todos los tests pasaron."
