#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
deploy_host="${RUST_TRAINING_DEPLOY_HOST:-23.238.60.229}"
deploy_user="${RUST_TRAINING_DEPLOY_USER:-rust-training-deploy}"
deploy_key="${RUST_TRAINING_DEPLOY_KEY:-${repo_root}/.git/rust-training-deploy}"
known_hosts="${repo_root}/deploy/known_hosts"

if [[ ! -r "${deploy_key}" ]]; then
    echo "Deployment key not found: ${deploy_key}" >&2
    exit 1
fi

if [[ ! -r "${known_hosts}" ]]; then
    echo "Pinned SSH host key not found: ${known_hosts}" >&2
    exit 1
fi

cd "${repo_root}"
cargo xtask build

for required in \
    site/index.html \
    site/async-book/index.html \
    site/async-book-zh/index.html \
    site/notes-blog/index.html
do
    if [[ ! -s "${required}" ]]; then
        echo "Build did not produce ${required}" >&2
        exit 1
    fi
done

tar -C site -czf - . | ssh \
    -T \
    -i "${deploy_key}" \
    -o BatchMode=yes \
    -o ConnectTimeout=15 \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile="${known_hosts}" \
    "${deploy_user}@${deploy_host}" deploy

curl --fail --silent --show-error --location \
    --retry 3 --retry-delay 2 \
    "https://sunp.xyz/" >/dev/null
curl --fail --silent --show-error --location \
    --retry 3 --retry-delay 2 \
    "https://sunp.xyz/async-book-zh/" >/dev/null
curl --fail --silent --show-error --location \
    --retry 3 --retry-delay 2 \
    "https://sunp.xyz/notes-blog/" >/dev/null

echo "Production deployment verified at https://sunp.xyz/"
