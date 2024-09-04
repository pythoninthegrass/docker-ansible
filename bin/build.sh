#!/usr/bin/env bash

set -euo pipefail

TLD="$(git rev-parse --show-toplevel)"
WORK_DIR="${TLD}/Dockerfiles"
ENV_FILE="${TLD}/.env"
[[ -f "${ENV_FILE}" ]] && export $(grep -v '^#' ${ENV_FILE} | xargs)
REGISTRY=${REGISTRY:-}
USER_NAME=${USER_NAME:-}
VERSION=${VERSION:-latest}

# Check that buildx is installed
if ! docker buildx version >/dev/null 2>&1; then
	echo "https://github.com/docker/buildx#installing"
	echo "docker buildx is not available. Please install it first. Exiting..."
	exit 1
fi

get_platform() {
	local os arch

	os=$(uname -s | tr '[:upper:]' '[:lower:]')
	arch=$(uname -m)

	case "${os}" in
		linux|darwin)
			os="linux"
			;;
		*)
			echo "Unsupported OS: ${os}" >&2
			exit 1
			;;
	esac

	case "${arch}" in
		x86_64)
			arch="amd64"
			;;
		aarch64|arm64)
			arch="arm64"
			;;
		armv7l)
			arch="arm/v7"
			;;
		*)
			echo "Unsupported architecture: ${arch}" >&2
			exit 1
			;;
	esac

	echo "${os}/${arch}"
}

build() {
	local dockerfile="$1"
	local service="$2"
	local platform="${PLATFORM:-$(get_platform)}"
	local tag

	if [[ -n "${REGISTRY}" && -n "${USER_NAME}" ]]; then
		tag="${REGISTRY}/${USER_NAME}/${service}"
	else
		tag="${service}"
	fi

	if [[ "${platform}" != "$(get_platform)" ]]; then
		docker buildx build \
			--platform="${platform}" \
			-f "${dockerfile}" \
			--build-arg VERSION="${VERSION}" \
			-t "${tag}" \
			--load \
			"${WORK_DIR}"
	else
		docker build \
			--platform="${platform}" \
			-f "${dockerfile}" \
			--build-arg VERSION="${VERSION}" \
			-t "${tag}" \
			"${WORK_DIR}"
	fi
}

usage() {
	echo "Usage: $(basename "$0") [OPTIONS] <dockerfile> <service>"
	echo "Options:"
	echo "  -p, --platform PLATFORM    Specify the target platform (e.g., linux/amd64)"
	echo "  -h, --help                 Display this help message"
}

main() {
	local PLATFORM=""
	local POSITIONAL=()

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-p|--platform)
				PLATFORM="$2"
				shift 2
				;;
			-h|--help)
				usage
				exit 0
				;;
			build)
				shift
				;;
			*)
				POSITIONAL+=("$1")
				shift
				;;
		esac
	done

	set -- "${POSITIONAL[@]}"

	if [[ $# -lt 2 ]]; then
		echo "Error: Missing required arguments." >&2
		usage
		exit 1
	fi

	local dockerfile="$1"
	local service="$2"

	build "$dockerfile" "$service"
}

main "$@"
