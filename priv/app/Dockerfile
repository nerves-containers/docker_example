FROM node:20-bookworm-slim

WORKDIR /app

COPY index.mjs /app/
COPY static/ /app/static/

ENTRYPOINT ["node", "/app/index.mjs"]
