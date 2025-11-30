#!/bin/bash
FILE=/src/data/config.yaml
if [[ -f "$FILE" ]]; then
    echo "$FILE exists."
else
    cp /config/config.yaml /src/data/
fi

FILE=/src/assets/icons/no-icon.svg
if [[ -f "$FILE" ]]; then
    echo "$FILE exists."
else
    cp /assets/icons/no-icon.svg /src/assets/icons/
fi

FILE=/src/assets/icons/other-icon.svg
if [[ -f "$FILE" ]]; then
    echo "$FILE exists."
else
    cp /assets/icons/other-icon.svg /src/assets/icons/
fi

hugo server --renderToDisk --minify --destination /src/public --disableLiveReload --disableFastRender 