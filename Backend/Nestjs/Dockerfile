# Build en dos etapas: la imagen final no lleva ni el código TypeScript ni las
# devDependencies. Node 20 sobre Debian slim (no Alpine) porque `bcrypt` compila
# binario nativo y con musl da más guerra de la que ahorra en tamaño.
FROM node:20-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
# `--omit=dev` deja fuera el compilador y los tipos: la imagen baja a ~1/3.
RUN npm ci --omit=dev && npm cache clean --force
# `dist` ya trae las migraciones compiladas a .js, y el data-source las busca
# con una ruta relativa que sirve igual en .ts y en .js — por eso no hace falta
# copiar `src` ni instalar ts-node (que es devDependency) en la imagen final.
COPY --from=build /app/dist ./dist
EXPOSE 3000
CMD ["node", "dist/main"]
