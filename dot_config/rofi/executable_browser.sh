#!/bin/bash

# Rofi browser mode - script mode
# Opens URLs or searches if not a link

if [ -z "$@" ]; then
    echo "🌐 Open URL or search"
    exit 0
fi

input="$@"

# Check if input looks like a URL or domain
if [[ "$input" =~ ^https?:// ]] || [[ "$input" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,} ]]; then
    if [[ ! "$input" =~ ^https?:// ]]; then
        url="https://$input"
    else
        url="$input"
    fi
    xdg-open "$url" &>/dev/null &
else
    query=$(echo "$input" | sed 's/ /+/g')
    xdg-open "https://www.google.com/search?q=$query" &>/dev/null &
fi

# Exit with code 0 to close rofi
exit 0
