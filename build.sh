#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

SEMVER_REGEX="^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(\\-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

main() {

  # parse tag
  # expected format: [service-name]/release/[version]

  tag="${args[0]}"
  dist="dist/generated"
  validate_tag $tag

  create_dist_folder "$dist"

  IFS='/' read -a arr <<< "$tag"
  
  service_name=${arr[0]}
  version=${arr[2]}

  FILES=$(find proto/$service_name -maxdepth 1 -name "*.proto")

  for proto in "$FILES"; do
      #echo "> $proto";
      #echo "Running in $script_dir/proto/$service_name/"
      protoc \
        -I proto/include \
        --proto_path="$script_dir"/proto/"$service_name" \
        --java_out=dist/generated \
        "$script_dir"/"$proto"
  done
  _jar=$service_name-events-${version}.jar
  # package generated files into jar
  jar cf $_jar "$dist" 

}

validate_tag() {

  tag=$1
  IFS='/' read -a arr <<< "$tag"

  # check tag contains only three parts
  if ! [[ ${#arr[@]} -eq 3 ]]; then
    die "The tag ${RED}$tag${NOFORMAT} has an invalid format."
  fi  
  
  service=${arr[0]}
  release=${arr[1]}
  version=${arr[2]}

  # validate service name
  # check that a folder with service name exists
  if ! [[ -d "$script_dir/proto/$service" ]]; then
    die "no service found with name: $service"
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
  flag=0
  param=''

  while :; do
    case "${1-}" in
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
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

