#!/usr/bin/env bash
# Git credential helper for Forgejo - reads token from Vault
# Install: git config --global credential.https://git.munchbox.cc.helper '/path/to/git-credential-forgejo.sh'

source ~/tools/munchbox/munchbox-env.sh 2>/dev/null

if [[ "$1" == "get" ]]; then
    TOKEN=$(vault kv get -field=token secret/forgejo 2>/dev/null)
    if [[ -n "$TOKEN" ]]; then
        echo "username=alex"
        echo "password=${TOKEN}"
    fi
fi
