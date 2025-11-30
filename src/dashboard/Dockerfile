# -------------------------------------------------------------------------------
# Munchbox Dash - Hugo Static Dashboard Site
#
# Project: Munchbox / Author: Alex Freidah
#
# Multi-stage image for the Munchbox dashboard landing page. Uses a Hugo
# extended image to compile the site into static assets during the build so
# the runtime container only serves static files from Nginx for predictable
# behavior in the Nomad cluster.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# HUGO BUILD STAGE
# -------------------------------------------------------------------------

FROM klakegg/hugo:ext-alpine AS builder
WORKDIR /src

# --- Copy complete site into the build context so Hugo sees all content ---
COPY . .

# --- Build static site output under /src/public for Nginx to serve ---
RUN hugo --minify

# -------------------------------------------------------------------------
# NGINX RUNTIME STAGE
# -------------------------------------------------------------------------

FROM nginx:alpine
WORKDIR /usr/share/nginx/html

# --- Replace default Nginx content with the Hugo build output ---
RUN rm -rf ./*
COPY --from=builder /src/public ./

EXPOSE 80

