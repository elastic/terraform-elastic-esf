#!/bin/bash

set -uo pipefail

eval "$(jq -r '@sh "VERSION=\(.version)"')"
ROOT_FOLDER=$(pwd)
CLONED_FOLDER="esf-repo-raw"
PACKAGE_FOLDER="esf-package"
GIT_REPO="https://github.com/elastic/elastic-serverless-forwarder.git"

function download() {
  mkdir -v -p "${CLONED_FOLDER}"
  git clone --depth 1 --branch "${VERSION}" "${GIT_REPO}" "${CLONED_FOLDER}"
  mkdir -v -p "${PACKAGE_FOLDER}"
} &>/dev/null

function create_package_folder() {
  pushd "${CLONED_FOLDER}"
  cp -v requirements.txt "../${PACKAGE_FOLDER}/"
  cp -v main_aws.py "${ROOT_FOLDER}/${PACKAGE_FOLDER}/"
  find {handlers,share,shippers,storage} -not -name "*__pycache__*" -type d -print0|xargs -t -0 -Idirname mkdir -v -p "${ROOT_FOLDER}/${PACKAGE_FOLDER}/dirname"
  find {handlers,share,shippers,storage} -not -name "*__pycache__*" -name "*.py" -exec cp -v '{}' "${ROOT_FOLDER}/${PACKAGE_FOLDER}/{}" \;
  popd
  rm -rf "${CLONED_FOLDER}"
} &>/dev/null

download
create_package_folder

jq -M -c -n --arg destination "${PACKAGE_FOLDER}" '{"package": $destination}'