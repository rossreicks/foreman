# syntax=docker/dockerfile:1.7

ARG NODE_VERSION=24.14.0
ARG PNPM_VERSION=10.33.2

FROM node:${NODE_VERSION}-bookworm-slim AS build
ARG PNPM_VERSION

ENV PNPM_HOME=/pnpm \
    PATH=/pnpm:$PATH \
    NEXT_TELEMETRY_DISABLED=1

WORKDIR /app

RUN npm install --global pnpm@${PNPM_VERSION}

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile --strict-peer-dependencies

# Keep this instruction explicit so source changes invalidate the Eve build.
COPY ./agent/ ./agent/
RUN sha256sum ./agent/agent.ts \
    && grep -n "defineDynamic\|EVE_MODEL" ./agent/agent.ts
COPY app ./app
COPY components ./components
COPY evals ./evals
COPY lib ./lib
COPY scripts ./scripts
COPY components.json css.d.ts next-env.d.ts next.config.ts postcss.config.mjs tsconfig.json ./

# The web build must not embed Eve into Next.js: production runs the Eve host
# and frontend as separate processes behind a reverse proxy.
ENV EVE_SELF_HOSTED=1
RUN pnpm run build && pnpm prune --prod

FROM node:${NODE_VERSION}-bookworm-slim AS runtime

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    EVE_SELF_HOSTED=1 \
    PORT=3000

WORKDIR /app

# Eve's Docker sandbox backend shells out to this client. The daemon is supplied
# by the deployment environment (normally through /var/run/docker.sock).
RUN apt-get update \
    && apt-get install --yes --no-install-recommends docker.io \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build --chown=node:node /app/package.json /app/pnpm-lock.yaml /app/pnpm-workspace.yaml ./
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/agent ./agent
COPY --from=build --chown=node:node /app/.eve ./.eve
COPY --from=build --chown=node:node /app/.output ./.output
COPY --from=build --chown=node:node /app/.next ./.next
COPY --from=build --chown=node:node /app/next.config.ts ./next.config.ts

USER node

EXPOSE 3000

# Compose can override this to run the frontend from the same image:
# node node_modules/next/dist/bin/next start --hostname 0.0.0.0 --port 3001
CMD ["node", "node_modules/eve/bin/eve.js", "start", "--host", "0.0.0.0", "--port", "3000"]
