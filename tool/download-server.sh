#!/usr/bin/env bash
set -e

# Downloads the sync-server executable from the artifacts of a GitLab job into the working directory

usage() {
    echo "Usage: $(basename "$0") --gitlab-base-url <url> --branch <branch> (--ci-job-token <token> | --private-token <token>)"
    echo ""
    echo "  --gitlab-base-url  Base URL of the GitLab instance (such as \$CI_SERVER_URL)"
    echo "  --branch           Branch/ref to download artifacts from (such as sync)"
    echo "  --ci-job-token     GitLab CI job token for authentication (such as \$CI_JOB_TOKEN)"
    echo "  --private-token    GitLab private access token for authentication (such as \$PRIVATE_TOKEN)"
    echo ""
    echo "Example:"
    echo "  $(basename "$0") --gitlab-base-url \$CI_SERVER_URL --branch sync --ci-job-token \$CI_JOB_TOKEN"
    exit 1
}

# GitLab artifact download configuration; https://docs.gitlab.com/ci/jobs/job_artifacts/
GITLAB_BASE_URL=""
PROJECT_ID="4"
# Note: Depending on the platform, the format (tar.gz, zip) of the contained archives might be different!
JOB_NAME="b:linux-x64-server"
BRANCH=""
CI_JOB_TOKEN=""
PRIVATE_TOKEN=""

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --gitlab-base-url) GITLAB_BASE_URL="$2"; shift 2 ;;
        --branch)          BRANCH="$2";           shift 2 ;;
        --ci-job-token)    CI_JOB_TOKEN="$2";     shift 2 ;;
        --private-token)   PRIVATE_TOKEN="$2";    shift 2 ;;
        *) echo "Unknown argument: $1"; usage ;;
    esac
done

if [ -z "$GITLAB_BASE_URL" ] || [ -z "$BRANCH" ]; then
    echo "Error: url, branch and one type of token for authentication are required."
    echo ""
    usage
fi

if [ -z "$CI_JOB_TOKEN" ] && [ -z "$PRIVATE_TOKEN" ]; then
    echo "Error: either --ci-job-token or --private-token must be provided."
    echo ""
    usage
fi

# URL-encode the job name (colon -> %3A)
JOB_NAME_ENCODED="${JOB_NAME//:/%3A}"

ARTIFACT_URL="${GITLAB_BASE_URL}/api/v4/projects/${PROJECT_ID}/jobs/artifacts/${BRANCH}/download?job=${JOB_NAME_ENCODED}"

echo "Downloading job artifacts from: ${ARTIFACT_URL}"

# Download the artifact
if [ -n "$CI_JOB_TOKEN" ]; then
    AUTH_HEADER="JOB-TOKEN: ${CI_JOB_TOKEN}"
else
    AUTH_HEADER="PRIVATE-TOKEN: ${PRIVATE_TOKEN}"
fi
curl --fail --location --header "$AUTH_HEADER" -o artifact.zip "$ARTIFACT_URL"

# Extract the outer artifact zip
unzip -o artifact.zip

# Find and extract the sync-server zip (flexible filename)
SYNC_SERVER_ARCHIVE=$(find ./artifacts -name "objectbox-sync-server-*.tar.gz" | head -1)
if [ -z "$SYNC_SERVER_ARCHIVE" ]; then
    echo "Error: Could not find objectbox-sync-server-*.tar.gz in artifacts"
    exit 1
fi

echo "Found sync-server archive: $SYNC_SERVER_ARCHIVE"
tar -xzf "$SYNC_SERVER_ARCHIVE"

# Verify sync-server executable exists
if [ ! -f "./sync-server" ]; then
    echo "Error: sync-server executable not found after extraction"
    exit 1
fi

chmod +x ./sync-server
ls -lh ./sync-server
./sync-server --version
