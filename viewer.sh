#!/bin/bash

# Sort the arguments in descending order
sorted_args=("$@")
IFS=$'\n' sorted_args=($(sort -r <<<"${sorted_args[*]}"))

jq '. | {"venue": .venue["name"], "location": .venue["location"]["contextLine"], "category": .venue["categories"][0]["name"], "date": .createdAt | strflocaltime("%Y-%m-%d"), "note": .shout}' "${sorted_args[@]}"
