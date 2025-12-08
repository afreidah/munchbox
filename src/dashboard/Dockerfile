# -------------------------------------------------------------------------------
# Munchbox Dashboard - Static Site Container
#
# Project: Munchbox / Author: Alex Freidah
#
# Multi-architecture build using Hugo on amd64 only. The static output is
# platform-agnostic, so we build once and copy to both arch variants.
# -------------------------------------------------------------------------------

# --- Build stage (amd64 only) ---
FROM --platform=linux/amd64 klakegg/hugo:ext-alpine AS builder

WORKDIR /src
COPY . .
RUN hugo --minify

# --- Runtime stage (multi-arch) ---
FROM nginx:alpine

WORKDIR /usr/share/nginx/html
RUN rm -rf ./*

COPY --from=builder /src/public ./

EXPOSE 80
