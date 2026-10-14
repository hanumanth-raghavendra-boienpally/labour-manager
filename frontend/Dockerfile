# syntax=docker/dockerfile:1

# Stage 1: build the static site. VITE_API_BASE_URL is intentionally left empty: the browser calls /api on the same origin
# and nginx forwards it to the backend, so one image works on any host without a rebuild.
FROM node:22-alpine AS build
WORKDIR /web
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
RUN npm run build

# Stage 2: nginx (non-root, listens on 8080) serves the build and proxies /api.
FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /web/dist /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --retries=3 CMD wget -qO- http://localhost:8080/ >/dev/null || exit 1
