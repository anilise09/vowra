# Vawra server image. Build from backend/:  docker build -t vawra-server .
# It still ships switched off: the platform must set VAWRA_SERVER_ENABLED=1,
# DATABASE_URL and the two keys (see docs/DEPLOY.md).

FROM node:22-bookworm-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npx tsc -p tsconfig.json \
 && node -e "require('fs').cpSync('src/migrations','dist/src/migrations',{recursive:true})" \
 && npm prune --omit=dev

FROM node:22-bookworm-slim
ENV NODE_ENV=production \
    VAWRA_ENV=production \
    VAWRA_HOST=0.0.0.0 \
    VAWRA_PORT=8797 \
    VAWRA_MEDIA_DIR=/data/media
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist/src ./dist/src
COPY --from=build /app/package.json ./
# Never root; the only writable place is the media volume.
RUN mkdir -p /data/media && chown -R node:node /data
USER node
VOLUME ["/data"]
EXPOSE 8797
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.VAWRA_PORT||8797)+'/v1/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "dist/src/server.js"]
