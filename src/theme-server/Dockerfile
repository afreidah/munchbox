# -------------------------------------------------------------------------------
# Theme Server - Static CSS Theme Files
#
# Project: Munchbox / Author: Alex Freidah
#
# Simple nginx server hosting custom Catppuccin CSS themes for various services.
# Provides consistent theming across apps that support external CSS injection.
# -------------------------------------------------------------------------------

FROM nginx:alpine

# Copy CSS files
COPY css/ /usr/share/nginx/html/css/

# Add CORS headers for cross-origin CSS loading (restricted to munchbox.cc)
RUN echo 'server { \
    listen 8078; \
    server_name _; \
    root /usr/share/nginx/html; \
    \
    location / { \
        # Allow CORS only from munchbox.cc subdomains \
        set $cors_origin ""; \
        if ($http_origin ~* "^https://([a-z0-9-]+\\.)?munchbox\\.cc$") { \
            set $cors_origin $http_origin; \
        } \
        add_header Access-Control-Allow-Origin $cors_origin always; \
        add_header Cache-Control "public, max-age=3600"; \
    } \
    \
    location = /health { \
        access_log off; \
        default_type text/plain; \
        return 200 "ok"; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 8078
