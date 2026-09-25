# Global build arg: must be declared before the first FROM to be usable in FROM.
ARG BASE_IMAGE=intersystemsdc/irishealth-community:latest

# --- Stage 1: build the Vue 3 frontend ---
FROM node:20-alpine AS frontend-builder

WORKDIR /app

COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci

COPY frontend/ ./
RUN npm run build

# --- Stage 2: IRIS application image ---
FROM ${BASE_IMAGE}

USER root

WORKDIR /opt/irisbuild
RUN chown -R ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisbuild

COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} iris/src /opt/irisbuild/src
COPY --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} docker/iris/installer/install.script /tmp/iris.script

# Serve the built SPA from the CSP directory registered by iris.script.
COPY --from=frontend-builder --chown=${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /app/dist/ /usr/irissys/csp/iris-operations/

USER ${ISC_PACKAGE_MGRUSER}

RUN iris start IRIS \
    && iris session IRIS < /tmp/iris.script \
    && iris stop IRIS quietly
