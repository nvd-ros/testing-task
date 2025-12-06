#!/usr/bin/env bash

# Enable security features:
#   -u:  Treat unset variables as an error when substituting
#   -e:  Exit immediately if a command exits with a non-zero status
#   -o pipefail: Return value of a pipeline
set -euo pipefail

## ---------------------------------------------------------------------------
## VARIABLES
## ---------------------------------------------------------------------------

CMDNAME=$(basename $0)
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

MINIKUBE_CPU="2"
MINIKUBE_MEMORY="2096"
MINIKUBE_DRIVER="docker"
SYSTEMWIDE="false"

BIN_DIR="./bin"
SYSTEMWIDE_BIN_DIR="/usr/local/bin"

# ---------------------------------------------------------------------------
# HELPERS FUNCTIONS
# ---------------------------------------------------------------------------

# Print the line where script failed:
#   E: The ERR trap is inherited by shell functions
set -E
failure() {
    local lineno=$1
    local msg=$2
    echo "$CMDNAME: Failed at $lineno: $msg"
}
trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

usage() {
    cat << USAGE >&2
usage: $CMDNAME [OPTIONS]

    OPTIONS:
        -d, --driver ARG     Driver for Minikube (docker or podman). Default: $MINIKUBE_DRIVER
        -c, --cpu ARG        amount of CPU for minikube (int, num cores). DEFAULT: $MINIKUBE_CPU
        -m, --memory ARG     amount of RAM for minikube (in mb, DEFAULT).  $MINIKUBE_MEMORY
        -s, --system         installs all components as system-wide. DEFAULT: $SYSTEMWIDE
        -h, --help           show this message
USAGE
exit 0
}

echoinfo() {
    local msg="$1"
    echo "$msg"
}

echoerr() {
    local msg="$1"
    local status="$2"
    echo -e "$CMDNAME error: $msg" 1>&2; exit "$status"; }

check_option_argument() {
    local option="$1"
    local arg="$2"
    local iter="$3"
    if [[ "${arg:-}" == "" ]]; then 
        echoerr "Empty argument for option: ${option:$iter:1} ";
        usage;
    fi
}

# ---------------------------------------------------------------------------
# PARSING ARGUMENTS
# ---------------------------------------------------------------------------

while [ $# -gt 0 ]; do
    case "$1" in
        --* )
            OPT=${1#*--}
            case "$OPT" in
                      driver=* ) MINIKUBE_DRIVER="${OPT#*=}";;
                      cpu=* ) MINIKUBE_CPU="${OPT#*=}";;
                     memory=* ) MINIKUBE_MEMORY="${OPT#*=}";;
                     system) SYSTEMWIDE="true";;
                       help ) usage ;;
                          * ) echoerr "Unknown argument: $1"; usage ;;
            esac ;;
        -* )
            OPT=${1#*-}
            if [[ ${#OPT} == 0 ]]; then echoerr "Empty option: $1"; usage ; fi
            for (( i=0; i<${#OPT}; i++ )); do
                case ${OPT:$i:1} in
                    d ) check_option_argument $OPT $2 $i
                        MINIKUBE_DRIVER="$2";
                        shift ;;
                    c ) check_option_argument $OPT $2 $i
                        MINIKUBE_CPU="$2";
                        shift ;;
                    m ) check_option_argument $OPT $2 $i
                        MINIKUBE_MEMORY="$2";
                        shift ;;
                    s ) SYSTEMWIDE="true";;
                    h ) usage ;;
                    * ) echoerr "Unknown argument: $1"; usage ;;
                esac
            done ;;
        help ) usage ;;
           * ) echoerr "Unknown argument: $1"; usage ;;
        esac
    shift
done

# ---------------------------------------------------------------------------
# MAIN LOGIC
# ---------------------------------------------------------------------------

# -------------------- Preparing environment --------------------

echoinfo "Starting the script"

echoinfo "$MINIKUBE_CPU"
echoinfo "$MINIKUBE_MEMORY"
echoinfo "$MINIKUBE_DRIVER"
echoinfo "$BIN_DIR"
echoinfo "$SYSTEMWIDE_BIN_DIR"
echoinfo "$SYSTEMWIDE"
echoinfo ""

echoinfo "Checking path for binaries"
if [ "$SYSTEMWIDE" = "false" ]; then
    echoinfo "Creating $BIN_DIR directory for all needed binaries"
    mkdir -pv "$BIN_DIR"
    export PATH="$PATH:$PWD/$BIN_DIR"
else
    echoinfo "System-wide $SYSTEMWIDE_BIN_DIR directory is used"
    BIN_DIR="$SYSTEMWIDE_BIN_DIR"
fi


if ! command -v minikube &> /dev/null; then
    echoinfo "Minikube not found. Downloading..."
    curl -L https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64 -o "$BIN_DIR/minikube"
    chmod +x "$BIN_DIR/minikube"
else
    echoinfo "Minikube already installed, skipping"
fi

echoinfo "Checking kubectl"
if ! command -v kubectl &> /dev/null; then
    echoinfo "kubectl not found. Downloading..."
    curl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/$(uname | tr '[:upper:]' '[:lower:]')/amd64/kubectl" -o /bin/kubectl
    chmod +x "$BIN_DIR/kubectl"
    kubectl version --client
else
    echoinfo "kubectl already installed, skipping."
fi

echoinfo "Checking $MINIKUBE_DRIVER driver"
if ! command -v "$MINIKUBE_DRIVER" &> /dev/null; then
    echoerr "Docker is not installed. Please install Docker before running this script and check if docker is running(Windows/WSL)"
    exit 1
else
    echoinfo "Docker is installed"
fi

echoinfo "Checking helm"
if ! command -v helm &> /dev/null; then
    echo "Helm not found. Installing locally..."
    HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep tag_name | cut -d '"' -f 4)
    curl -L https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -o helm.tar.gz
    tar -zxvf helm.tar.gz
    mv -v linux-amd64/helm "$BIN_DIR/helm"
    chmod +x "$BIN_DIR/helm"
    rm -rfv linux-amd64 helm.tar.gz
else
    echo "Helm is already installed."
fi


echoinfo "Checking if minikube cluster exists"
if minikube status &> /dev/null; then
    echo "Minikube cluster is already running."
else
    echo "Minikube is not running. Starting..."
    minikube start --driver=docker --memory=$MINIKUBE_MEMORY --cpus=$MINIKUBE_CPU
fi

# -------------------- Installing applications --------------------



echoinfo "DONE"
exit 0
