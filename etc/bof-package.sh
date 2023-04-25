#!/usr/bin/env bash

set -e

#LOCAL_HELM_MOJALOOP_REPO_URI=${HELM_MOJALOOP_REPO_URI:-'https://docs.mojaloop.io/charts/repo'}
LOCAL_HELM_MOJALOOP_REPO_URI=https://docs.mojaloop.io/charts/repo

#
# Script to Package all charts, and create an index.yaml in ./repo directory
#

trap 'echo "Command failed...exiting. Please fix me!"' ERR

echo $0
echo "Removing old charts..."
find ./ -name "charts"| xargs rm -Rf

mkdir -p ./repo

if [ "$1" ]; then
    declare -a charts=("$1")
else
    declare -a charts=(
        # Example Backend Dependency Charts
        mojaloop/example-backend
        # Common Charts
        mojaloop/common
        # Mojaloop BoF Charts
        mojaloop/role-assignment-service
        mojaloop/reporting-hub-bop-experience-api-svc
        mojaloop/reporting-hub-bop-shell
        mojaloop/reporting-hub-bop-api-svc
        mojaloop/reporting-events-processor-svc
        mojaloop/security-role-perm-operator-svc
        mojaloop/reporting-hub-bop-role-ui
        mojaloop/reporting-hub-bop-trx-ui
        mojaloop/reporting-legacy-api
        mojaloop/security-hub-bop-kratos-ui
        mojaloop/bof
        ## placeholder
        # Mojaloop Core Charts
        mojaloop/admin-api-svc
        mojaloop/fspiop-transfer-api-svc
        mojaloop/chart-service
        mojaloop/chart-admin
        mojaloop/account-lookup-service
        # Main Mojaloop Helm Chart 
        mojaloop/mojaloop
    )
fi

for chart in "${charts[@]}"
do
    if [ -z $BUILD_NUM ] || [ -z $GIT_SHA1 ]; then # we're most likely not running in CI
        # Probably running on someone's machine
        helm package -u -d ./repo "$chart"
    elif [ -z $GITHUB_TAG ]; then # we're probably running in CI, but this is not a job triggered by a tag
        set -u
        # When $GITHUB_TAG is not present, we'll build a development version. This versioning
        # scheme, utilising the incrementing "BUILD_NUM" means users can request the latest
        # development version using the --devel argument to `helm upgrade` or `helm install`.
        # Development versions can be found with `helm search --devel`. Additionally, it is
        # possible to specify a development version in requirements.yaml.
        CURRENT_VERSION=$(grep '^version: [0-9]\+\.[0-9]\+\.[0-9]\+\s*$' "$chart/Chart.yaml" | cut -d' ' -f2)
        NEW_VERSION="$CURRENT_VERSION-$BUILD_NUM.${GIT_SHA1:0:7}"
        helm package -u -d ./repo "$chart" --version="$NEW_VERSION"
        set +u
    else # we're probably running in CI, this is a job triggered by a tag/release
        # When $GITHUB_TAG is present, we're actually releasing the chart- so we won't modify any
        # versions
        helm package -u -d ./repo "$chart"
    fi
done

cd ./repo

helm repo index . --url $LOCAL_HELM_MOJALOOP_REPO_URI

set +x

echo -e "\
 Packaging completed.\n \
Ensure you check the output for any errors. \n \
Ignore any http errors when connecting to \"local\" chart repository.\n \
\n \
Run the following command to serve a local repository: helm serve --repo-path ./repo \n \
\n \
Happy Helming!
"
