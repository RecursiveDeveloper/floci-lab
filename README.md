# Floci EKS Lab

This project provides a fully local, zero-cost AWS sandbox for learning EKS. A Dockerized AWS API emulator (floci) stands in for real AWS services, and an EKS demo walks through cluster creation, kubeconfig management, and IAM access-key rotation — all on `localhost:4566` instead of a real AWS account.

## Project Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          Host machine                           │
│                                                                 │
│  ┌───────────────┐   us-east-1 API calls   ┌──────────────────┐ │
│  │  eks_demo/    │ ──────────────────────► │  Floci emulator  │ │
│  │  aws + kubectl│        localhost:4566   │  (floci/floci)   │ │
│  └──────┬────────┘                         └───────┬──────────┘ │
│         │                                          │ docker.sock│
│         │ kubeconfig (token webhook)               ▼            │
│         │                              ┌──────────────────────────┐
│         └──────────────────────────────►   floci-aws-eks-dev-cluster
│                                        │   k3s control plane      │
│                                        │   coredns, metrics-server│
│                                        │   workloads (apache, ...)│
│                                        └──────────────────────────┘
│                                                 │
│              ┌──────────────────────────────────┤
│              ▼                                  ▼
│  floci-aws-ecr-registry               infra/data/ (JSON state,
│  floci-aws-ui                         eks webhook/keys, logs)
└─────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
floci-lab/
├── README.md
├── .gitignore
├── .gitattributes
├── infra/
│   ├── docker-compose.yml        # floci-aws-emulator service definition
│   ├── deploy.sh                 # builds and starts the emulator
│   ├── destroy.sh                # full teardown: containers, volumes, networks, data
│   └── data/                     # persisted emulator state (generated at runtime)
│       ├── *.json                # ec2, iam, eks, kms, s3, cloudwatch snapshots
│       └── eks/                  # OIDC keys, registries, token webhook per cluster
└── eks_demo/
    ├── credential_setup.sh       # exports AWS credentials and endpoint variables
    ├── deploy_eks_cluster.sh     # creates IAM user + access keys and the EKS cluster
    └── apache_deployment.yml     # sample Apache deployment + LoadBalancer service
```

## Features

- **Local AWS API:** Every `aws` CLI command is pointed at the emulator via `AWS_ENDPOINT_URL=http://localhost:4566`, with no real AWS account or billing.

- **EKS emulation:** Creating a cluster spins up an isolated k3s sidecar container (`floci-aws-eks-dev-cluster`), so `kubectl` interacts with a real Kubernetes API server backed by emulated AWS APIs.

- **IAM access-key rotation:** `deploy_eks_cluster.sh` generates a dedicated `eks-admin` user, rotates its keys on every run, and injects them into `credential_setup.sh` automatically.

## Prerequisites

Before deploying, ensure the following are installed:

| Tool | Purpose |
| --- | --- |
| Docker (with Compose v2) | Runs the emulator and provisions the Docker socket it needs |
| AWS CLI | All AWS API calls (v2 recommended) |
| curl | Used by the deploy script health check |
| kubectl | Interacting with the emulated cluster |

> **Note:** The EKS container mounts `/var/run/docker.sock` into the floci service. This privileges `floci` to launch its own sibling containers (cluster control plane, registry, UI) — required for full EKS simulation.

## Usage

### Step 1 — Deploy the Emulator

From `infra/`, build and start the emulated AWS endpoint:

```
cd infra
./deploy.sh
```

The script waits for `http://localhost:4566/_floci/health` and then keeps the emulator running in the background (detached).

### Step 2 — Create the EKS Cluster

From `eks_demo/`, provision IAM, the cluster, and your kubeconfig:

```
cd eks_demo
./deploy_eks_cluster.sh
```

This script:

1. Recreates the `eks-admin` IAM user and rotates its access keys.
2. Rewrites `credential_setup.sh` with the fresh credentials (sourced by every later run).
3. Creates (or reuses) the `dev-cluster` cluster on `subnet-default-us-east-1-a` with the `eks-role` ARN.
4. Runs `aws eks update-kubeconfig --name dev-cluster` so `kubectl` targets the emulated control plane.
5. Prints the initial cluster resources via `kubectl get all --all-namespaces`.

### Step 3 — Destroy Everything

From `infra/`, fully reset the lab:

```
cd infra
./destroy.sh
```

The teardown order matters and is handled for you: floci-spawned sidecar containers are removed first (they attach to the compose network), then the compose stack, then floci-owned volumes and networks, and finally the persisted `./data` directory.

## Connecting to the EKS Cluster

`deploy_eks_cluster.sh` already configures the kubeconfig, but you can re-run it manually:

```
cd eks_demo
source credential_setup.sh   # do NOT run it with ./credential_setup.sh
```

Executing it with `./credential_setup.sh` spawns a child shell — the variables are exported there and disappear as soon as the script exits, leaving `update-kubeconfig` to pick up stale or unrelated `AWS_*` variables (for example, credentials from a real AWS account) and replaying requests against the wrong endpoint.

```
aws eks update-kubeconfig --name dev-cluster
kubectl get nodes
kubectl get pods -A
```

The token is resolved by a webhook written to `infra/data/eks/webhook/dev-cluster/token-webhook.yaml`, which authenticates against the emulator — that is why the state directory must persist between runs.

## Scripts

- [`infra/deploy.sh`](infra/deploy.sh): Builds and starts the emulator with `FLOCI_STORAGE_MODE=hybrid` (in-memory + JSON persistence to `./data`).

- [`infra/destroy.sh`](infra/destroy.sh): Full cleanup. Wipes the k3s state volume `floci-aws-eks-dev-cluster` — without this, `kubectl` re-attaches old pod state on the next deploy.

- [`eks_demo/deploy_eks_cluster.sh`](eks_demo/deploy_eks_cluster.sh): One-shot orchestration of IAM + cluster + kubeconfig.

## Requirements

### Tooling

| Tool | Version |
| --- | --- |
| Docker Engine | >= 24 with Compose v2 plugin |
| AWS CLI | >= v2 |
| kubectl | compatible with the k3s version bundled by floci |

### Endpoints and Defaults

| Setting | Value | Source |
| --- | --- | --- |
| Emulator endpoint | `http://localhost:4566` | `docker-compose.yml`, `credential_setup.sh` |
| Region | `us-east-1` | `credential_setup.sh`, env defaults |
| Account ID (emulated) | `000000000000` | hardcoded in `deploy_eks_cluster.sh` |
| Cluster name | `dev-cluster` | `deploy_eks_cluster.sh` |
| IAM user | `eks-admin` | `deploy_eks_cluster.sh` |

## Customization

Edit the referenced scripts to adapt the lab:

- Change the cluster name, IAM user, or role ARN — `CLUSTER_NAME`, `IAM_USER`, and `CLUSTER_ARN_ROLE` at the top of [`deploy_eks_cluster.sh`](eks_demo/deploy_eks_cluster.sh).
- Apply a workload after cluster creation:

```
cd eks_demo
source credential_setup.sh
kubectl apply -f apache_deployment.yml
```

- `apache_deployment.yml` deploys 5 `httpd:2.4` pods with liveness/readiness probes and a `LoadBalancer` service on port 80.

## Notes

- The `infra/data/` directory is generated state, never checked in — deleting it is equivalent to destroying the account.
- EKS state lives in the `floci-aws-eks-dev-cluster` Docker volume; only `destroy.sh` cleans it correctly. `docker compose down` alone is not sufficient.
- Credentials in `credential_setup.sh` are emulator-local and regenerated per deploy — they are not real AWS keys.
- Costs are zero: everything is CPU-local, and emulated EC2/networking resources live as JSON snapshots.
