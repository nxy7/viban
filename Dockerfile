# Viban PostgreSQL Container
#
# This container only runs PostgreSQL. The Viban backend runs natively on the host
# to have access to local tools (claude, gemini, etc.)
#
# Usage:
#   docker build -t viban-db .
#   docker run -d --name viban-db \
#     -p 5432:5432 \
#     -v viban-pgdata:/var/lib/postgresql/data \
#     viban-db
#
# Then run the backend natively:
#   cd backend && ./scripts/build.sh
#   DATABASE_URL=ecto://postgres:postgres@localhost/viban_prod \
#   SECRET_KEY_BASE=$(openssl rand -base64 48) \
#   PHX_HOST=localhost \
#   _build/prod/rel/viban/bin/viban start

FROM postgres:16-alpine

ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres
ENV POSTGRES_DB=viban_prod

# Enable logical replication for Electric sync
RUN echo "wal_level = logical" >> /usr/local/share/postgresql/postgresql.conf.sample && \
    echo "max_wal_senders = 10" >> /usr/local/share/postgresql/postgresql.conf.sample && \
    echo "max_replication_slots = 10" >> /usr/local/share/postgresql/postgresql.conf.sample

EXPOSE 5432

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
    CMD pg_isready -U postgres -d viban_prod || exit 1
