#!/bin/bash
echo "build tailwind"
npm run build
echo "start server"
hugo server --disableFastRender


