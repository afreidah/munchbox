#!/bin/bash
# -------------------------------------------------------------------------------
# Dashboard Run - Development Server
#
# Project: Munchbox / Author: Alex Freidah
#
# Builds Tailwind CSS and starts Hugo development server for the Munchbox
# dashboard. Used for local development with live reload.
# -------------------------------------------------------------------------------
echo "build tailwind"
npm run build
echo "start server"
hugo server --disableFastRender


