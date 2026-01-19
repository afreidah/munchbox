# -------------------------------------------------------------------------------
# Munchbox Dashboard - Static Site Container
#
# Project: Munchbox / Author: Alex Freidah
#
# Multi-architecture build using Hugo. The static output is platform-agnostic,
# so we let Hugo run natively on the build host architecture.
# -------------------------------------------------------------------------------

# --- Build stage (hugomods/hugo supports multi-arch including arm64) ---
FROM hugomods/hugo:exts AS builder

WORKDIR /src
COPY . .
RUN hugo --minify

# --- Runtime stage (multi-arch) ---
FROM nginx:alpine

WORKDIR /usr/share/nginx/html
RUN rm -rf ./*

COPY --from=builder /src/public ./

EXPOSE 80
