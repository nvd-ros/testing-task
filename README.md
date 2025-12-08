# Test Project
Test Project with minikube, Argocd, Grafana and VictoriaMetrics

---
## Table of Contents
- [About](#about)
- [Tech Stack](#tech-stack)
- [Requirements](#requirements)

---
## About

This repository provides an automated setup for a Kubernetes monitoring stack using **ArgoCD** and **Minikube**. It includes:

- Custom Helm charts for deploying the `spam2000` application.
- Pre-configured ArgoCD applications for:
  - **Grafana Operator**
  - **Grafana custom resources: `grafana`, `dashboards` and `datasources`**
  - **VictoriaMetrics Operator**
  - **Custom resources: `vmagent`, `vmservicescrape`, and `vmsingle`**
  - **Node Exporter**
  - **Kube State Metrics**
  - **Custom spam2000 application**

The repository also includes a **cluster creation script** (`bootstrap.sh`) that automates the setup of a local Kubernetes cluster using **Minikube**. By default, the script uses **Docker**, but you can configure it to use **Podman** or **VirtualBox** instead. Use to see more:

```bash
./bootstrap.sh --help
```
---
## Tech Stack

This project uses the following technologies and tools:

- **Kubernetes** – Container orchestration platform
- **Minikube** – Local Kubernetes cluster for testing and development
- **ArgoCD** – Continuous delivery tool for managing Kubernetes applications
- **Helm** – Kubernetes package manager for deploying applications
- **Docker / Podman (container runtimes) or VirtualBox (VM driver)** – Used by Minikube
- **Grafana Operator** – Manages Grafana custom resources (CRDs)
- **VictoriaMetrics Operator** – Manages VictoriaMetrics custom resources (CRDs)
- **Node Exporter** – Exposes node-level metrics
- **Kube State Metrics** – Exposes cluster state metrics
- **Bash** – Scripts for cluster automation (`bootstrap.sh`)
- **Node.js / NestJS** – Runtime and framework for the custom `spam2000` application (runs inside the pod)

## Requirements

Before running the script, make sure your system meets the following requirements:

- **Operating System:** Linux (tested on Ubuntu and WSL2)
- **Docker:** Must be installed and running (used by default for Minikube)
- **Podman** or **VirtualBox** (optional) – if you want to use these instead of Docker
- **kubectl** – command-line tool for interacting with Kubernetes
- **Minikube** – installed

Minikube / Helm / kubectl – If not present, `bootstrap.sh` will install them into the `bin/` directory in the repository root by default, so **no sudo privileges are required**.
Use to see more:

```bash
./bootstrap.sh --help
```


