#!/bin/bash
# Copyright 2020 Mavenir
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

##############################################
#usage: ./buildall.sh <InitContainer_VERSION>
#InitContainer_VERSION:(Mandatory): This argument can be passed from jenkins job or manual, Artifact init container image will be tagged with this version.
##############################################

set -e

BASE_DISTRO_IMAGE="alpine"
BASE_DISTRO_VERSION="3.11.3"

MICROSERVICE_NAME="xgvela-svc-init"
MICROSERVICE_VERSION=$1

ARTIFACTS_PATH="./artifacts"
COMMON_ARG="--no-cache"
#COMMON_ARG=""

##NANO SEC timestamp LABEL, to enable multiple build in same system
echo -e "[XGVela-SVC-INIT-BUILD] Build MICROSERVICE_NAME:$MICROSERVICE_NAME, Version:$MICROSERVICE_VERSION"
docker build --rm \
             $COMMON_ARG \
             --build-arg BASE_DISTRO_IMAGE=$BASE_DISTRO_IMAGE \
             --build-arg BASE_DISTRO_VERSION=$BASE_DISTRO_VERSION \
             -f ./build_spec/init_dockerfile \
             -t $MICROSERVICE_NAME:$MICROSERVICE_VERSION .

echo -e "[XGVela-SVC-INIT-BUILD] Setting Artifacts Environment"
rm -rf $ARTIFACTS_PATH
mkdir -p $ARTIFACTS_PATH
mkdir -p $ARTIFACTS_PATH/images

echo -e "[XGVela-SVC-INIT-BUILD] Releasing Artifacts... @$ARTIFACTS_PATH"
docker save $MICROSERVICE_NAME:$MICROSERVICE_VERSION | gzip > $ARTIFACTS_PATH/images/$MICROSERVICE_NAME-$MICROSERVICE_VERSION.tar.gz

docker rmi -f $MICROSERVICE_NAME:$MICROSERVICE_VERSION
