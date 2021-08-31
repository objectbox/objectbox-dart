#!/usr/bin/env bash
set -euox pipefail

sudo apt-get update
sudo apt-get install --yes --no-install-recommends $@