#!/bin/bash

unset -v number # Last closed pull request number

while getopts n: flag; do
    case "${flag}" in
    n) number=${OPTARG} ;;
    esac
done

: ${number:?Missing -n}

# Auth for GH Cli
# gh auth login --with-token < mytoken.txt

# Parameters
SAVEIFS=$IFS
IFS=$'\n'
SYNC_FILE=".github/sync.yml"
PATTERN='.*..-repo-destination'

# Write to $SYNC_FILES the repos to be synced
REPOS=($(gh repo list --source \
        --json name \
        --jq '.[].name' \
        --limit 1000 |
        grep -e $PATTERN))
echo -e "group:\n  repos: |" > ${SYNC_FILE}
for repo in "${REPOS[@]}"; do
    echo "    ${repo}" >> ${SYNC_FILE}
done

# Get list of all files changed within the last pull request
#   1. Current limitation to deleted files not being synced without deleteOrphaned.
#      Since the children is populated by another repo, this flag is not a viable option
MODIFIED_FILES=($(gh pr diff $number --name-only))
# echo -e "Modified Files: \n    ${MODIFIED_FILES[@]}\n"

# Get list of files that won't be synced
declare -a EXCLUDED_FILES=(README.md)
declare -a EXCLUDED_FOLDERS=(excluded)
for folder in "${EXCLUDED_FOLDERS[@]}"; do
    FILES=($(find $folder -type f -follow -print))
    EXCLUDED_FILES=("${EXCLUDED_FILES[@]}" "${FILES[@]}")
done
# echo -e "Excluded Files: \n    ${EXCLUDED_FILES[@]}\n"

# Filter out from MODIFIED_FILES the invalid files
for file in "${EXCLUDED_FILES[@]}"; do
    for i in "${!MODIFIED_FILES[@]}"; do
        if [[ ${MODIFIED_FILES[i]} = $file ]]; then
            unset "MODIFIED_FILES[i]"
        fi
    done
done
# echo -e "Modified Files: \n    ${MODIFIED_FILES[@]}\n"

# Define, for each repo, the list of files to be synced
echo "  files:" >> ${SYNC_FILE}
for file in "${MODIFIED_FILES[@]}"; do
    echo -e "    - source: ${file}\n      dest: ${file}" >> ${SYNC_FILE}
done

# Restore the Internal Field Separator
IFS=$SAVEIFS