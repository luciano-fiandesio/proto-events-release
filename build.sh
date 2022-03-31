#!/usr/bin/env bash

#
# Automate the generation of jar files from Protobuf schema definitions
#
# This script is meant to be used in a Continuous Integration pipeline.
# It uses git tags to select the service for which to trigger the protoc code generation.
# After the code generation, it packaged the classes into a jar.
# The jar is named after the area and service name: area-my-service-1.2.3.jar
#
# Usage: ./build.sh <tag>
#
# Example: ./build.sh product/my-service/release/1.2.3
#
# The -d/--debug flag allows to use the "test" folder for testing and debugging purposes
# 
# Example: ./build.sh -d test/my-test-service/release/1.2.3
#
# author: Luciano Fiandesio <luciano@fiandes.io>
#

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

SEMVER_REGEX="^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(\\-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"
VALID_AREAS=("user" "product" "finance" "adv")

main() {

  # parse tag
  # expected format: [area]/[service-name]/release/[version]

  tag="${args[0]}"
  dist="dist/generated"
  validate_tag $tag

  create_dist_folder "$dist"

  IFS='/' read -a arr <<< "$tag"
  
  area=${arr[0]}
  service_name=${arr[1]}
  version=${arr[3]}

  FILES=$(find proto/$area/$service_name -maxdepth 1 -name "*.proto")

  for proto in "$FILES"; do
      #echo "> $proto";
      #echo "Running in $script_dir/proto/$service_name/"
      protoc \
        -I proto/include \
        --proto_path="$script_dir"/proto/"$area"/"$service_name" \
        --java_out=dist/generated \
        "$script_dir"/"$proto"
  done
  _jar=$area-$service_name-events-${version}.jar
  # package generated files into jar
  jar cf $_jar "$dist" 

}

validate_tag() {

  tag=$1
  IFS='/' read -a arr <<< "$tag"

  # check tag contains 4 parts
  if ! [[ ${#arr[@]} -eq 4 ]]; then
    die "The tag ${RED}$tag${NOFORMAT} has an invalid format."
  fi  
  
  area=${arr[0]}
  service=${arr[1]}
  release=${arr[2]}
  version=${arr[3]}

  # validate service name
  # check that a folder with service name exists
  if ! [[ -d "$script_dir/proto/$area/$service" ]]; then
    die "no service found with name: $area/$service"
  fi

  if [[ $debug == 1  ]]; then
    VALID_AREAS+=("test")
  fi

  # validate area name
  if [[ ! " ${VALID_AREAS[*]} " =~ " ${area} " ]]; then
    die "invalid area name: $area"
  fi

  # validate second part of tag
  if [[ $release != "release" ]] 
  then 
    die "The tag ${RED}$tag${NOFORMAT} is invalid. Expected 'release' between service and version!" 
  fi

  # validate version
  if ! [[ "$version" =~ $SEMVER_REGEX ]]; then
    die "The version ${RED}$version${NOFORMAT} specified in the tag is not valid!"
  fi
  
}

create_dist_folder() {
  mkdir -p $1
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "💀 - $msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  debug=0
  
  while :; do
    case "${1-}" in
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -d | --debug) debug=1 ;; # debug flag
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # check required params and arguments
  [[ ${#args[@]} -eq 0 ]] && die "Missing script arguments"

  return 0
}

parse_params "$@"
setup_colors

# script logic here
main

