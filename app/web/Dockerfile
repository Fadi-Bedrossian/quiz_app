FROM node:20-alpine AS build
WORKDIR /src

COPY package.json ./
RUN npm install
COPY . .

RUN npm run build

FROM nginxinc/nginx-unprivileged:stable-alpine-slim

USER root
RUN apk upgrade --no-cache
USER 101

COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /src/dist /usr/share/nginx/html

EXPOSE 8080
