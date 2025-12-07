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
MINIKUBE_MEMORY="4096"
MINIKUBE_DRIVER="docker"
SYSTEMWIDE="false"

BIN_DIR="./bin"
SYSTEMWIDE_BIN_DIR="/usr/local/bin"

ARGOCD_RELEASE="argocd"
ARGOCD_VERSION="9.1.6"
ARGOCD_NS="argocd"

TIMEOUT="180s"
MONITORING_NS="monitoring"

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
        -d, --driver ARG     Driver for Minikube (virtualbox, docker or podman). Default: $MINIKUBE_DRIVER
        -c, --cpu ARG        amount of CPU for minikube (int, num cores). DEFAULT: $MINIKUBE_CPU
        -m, --memory ARG     amount of RAM for minikube (in mb, DEFAULT).  $MINIKUBE_MEMORY
        -s, --system         installs all components as system-wide. DEFAULT: $SYSTEMWIDE
        -h, --help           show this message
USAGE
exit 0
}

echoinfo() {
    local msg="$1"
    echo -e "$msg"
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

echoinfo "Checking path for binaries"
if [[ "$SYSTEMWIDE" = "false" ]]; then
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
    curl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/$(uname | tr '[:upper:]' '[:lower:]')/amd64/kubectl" -o "$BIN_DIR/kubectl"
    chmod +x "$BIN_DIR/kubectl"
    kubectl version --client
else
    echoinfo "kubectl already installed, skipping."
fi

echoinfo "Checking $MINIKUBE_DRIVER driver"
if ! command -v "$MINIKUBE_DRIVER" &> /dev/null; then
    echoerr "$MINIKUBE_DRIVER is not installed. Please install $MINIKUBE_DRIVER before running this script. For Docker be sure it is running"
else
    echoinfo "$MINIKUBE_DRIVER is installed"
fi

echoinfo "Checking helm"
if ! command -v helm &> /dev/null; then
    echoinfo "Helm not found. Installing locally..."
    HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep tag_name | cut -d '"' -f 4)
    curl -L https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -o helm.tar.gz
    tar -zxvf helm.tar.gz
    mv -v linux-amd64/helm "$BIN_DIR/helm"
    chmod +x "$BIN_DIR/helm"
    rm -rfv linux-amd64 helm.tar.gz
else
    echoinfo "Helm is already installed."
fi

echoinfo "Checking if minikube cluster exists"
if $MINIKUBE_DRIVER inspect minikube &> /dev/null; then
    echoinfo "Minikube cluster is already running."
else
    echoinfo "Minikube is not running. Starting..."
    minikube start --driver=$MINIKUBE_DRIVER --memory=$MINIKUBE_MEMORY --cpus=$MINIKUBE_CPU
fi

# -------------------- Installing ArgoCD and Applications --------------------

echoinfo "Checking argocd namespace"
if ! kubectl get ns argocd &>/dev/null; then
    echoinfo "Creating namespace argocd..."
    kubectl create ns argocd
else
    echoinfo "argocd namespace exists"
fi

echoinfo "Checking argo helm repo"
if ! helm repo list | grep -q "argo"; then
    echoinfo "Adding Argo Helm repo..."
    helm repo add argo "https://argoproj.github.io/argo-helm"
else
    echoinfo "argo helm repo exists"
fi

echoinfo "Updating helm repos"
helm repo update

if ! helm list -n "$ARGOCD_NS" | grep -q "$ARGOCD_RELEASE"; then
    echoinfo "Installing ArgoCD..."
    helm install "$ARGOCD_RELEASE" argo/argo-cd \
        -n "$ARGOCD_NS" --create-namespace \
        --version "$ARGOCD_VERSION" \
        --set server.extraArgs[0]="--insecure"
else
    echoinfo "Release $ARGOCD_RELEASE exists. Upgrading..."
    helm upgrade "$ARGOCD_RELEASE" argo/argo-cd \
        -n "$ARGOCD_NS" \
        --set server.extraArgs[0]="--insecure"
fi

echoinfo "Waiting for argocd is ready"
kubectl wait --for='jsonpath={.status.conditions[?(@.type=="Ready")].status}=True' \
  -n "$ARGOCD_NS" pod \
  -l app.kubernetes.io/instance=argocd,app.kubernetes.io/component!=redis-secret-init \
  --timeout="$TIMEOUT"

echoinfo "Applying argocd resources"
kubectl apply -f argocd/ --recursive

ARGOCD_PASS=$(kubectl get secret -n "$ARGOCD_NS" argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echoinfo "\nFor ArgoCD"
if ps aux | grep -v grep | grep 'kubectl .*port-forward .*svc/argocd-server .*3000:80' &>/dev/null; then
    echoinfo "Port-forwarding exists, use locahost:3000"
else
    echoinfo "Starting port-forward..."
    nohup kubectl port-forward -n "$ARGOCD_NS" svc/argocd-server 8000:80 &> /dev/null &
    echoinfo "Port forwarding was created, use locahost:3000"
fi
echoinfo "Credentials are: admin:$ARGOCD_PASS\n"

echoinfo "Waiting for monitoring is ready"
kubectl apply -f monitoring
kubectl wait -n argocd application monitoring --for='jsonpath={.status.sync.status}=Synced' --timeout="$TIMEOUT"

GRAFANA_PASS=$(kubectl get secret -n "$MONITORING_NS" monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d)

echoinfo "\nFor Grafana"
if ps aux | grep -v grep | grep 'kubectl .*port-forward .*svc/monitoring-grafana .*4000:80' &>/dev/null; then
    echoinfo "Port-forwarding exists, use locahost:4000"
else
    echoinfo "Starting port-forward..."
    nohup kubectl port-forward -n monitoring svc/monitoring-grafana 7000:80 &> /dev/null &
    echoinfo "Port forwarding was created, use locahost:4000"
fi
echoinfo "Credentials are: admin:$GRAFANA_PASS\n"

echoinfo "Starting port-forward for vmagent..."
nohup kubectl port-forward -n monitoring svc/vmagent-monitoring-vmks 8429:8429 &> /dev/null &
echoinfo "Port forwarding was created, use locahost:8429"

echoinfo "DONE"
exit 0
