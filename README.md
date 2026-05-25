# GitOps Playground

A local GitOps playground that spins up a [kind](https://kind.sigs.k8s.io/) Kubernetes cluster and installs [ArgoCD](https://argoproj.github.io/cd/) using Terraform — no cloud account required.

> **Disclaimer:** this playground is for demonstrative purposes only. It is not intended for production use. Configuration choices (local state, insecure ArgoCD, single-node cluster) are deliberately simplified to make it easy to run locally.

## Structure

```
gitops-playground/
├── argocd/                        # ArgoCD Application manifests (desired state)
│   ├── level-1/                   # Helm chart source
│   │   └── kubeview.yaml
│   ├── level-2/                   # Raw Kubernetes manifests
│   │   ├── echo-server.yaml
│   │   └── manifests/
│   │       ├── deployment.yaml
│   │       └── service.yaml
│   ├── level-3/                   # Kustomize overlays
│   │   ├── dev.yaml
│   │   ├── prod.yaml
│   │   └── manifests/
│   │       ├── base/
│   │       │   ├── kustomization.yaml
│   │       │   ├── deployment.yaml
│   │       │   └── service.yaml
│   │       └── overlays/
│   │           ├── dev/
│   │           │   └── kustomization.yaml
│   │           └── prod/
│   │               └── kustomization.yaml
│   └── level-4/                   # Infrastructure managed by ArgoCD
│       └── keda.yaml
├── terraform/                     # Infrastructure as code
│   ├── .helm/
│   │   └── repositories.yaml
│   ├── main.tf
│   ├── providers.tf
│   ├── variables.tf
│   └── outputs.tf
├── .gitignore
└── README.md
```

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| [Docker](https://docs.docker.com/get-docker/) | Engine or Desktop, running | [docs.docker.com](https://docs.docker.com/get-docker/) |
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.5 (tested with 1.15.4) | [developer.hashicorp.com](https://developer.hashicorp.com/terraform/install) |
| [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) | >= 0.20 | [kind.sigs.k8s.io](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | any recent version | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |

### Docker

Make sure Docker is running before starting. You can verify with:

```bash
docker info
```

> **Memory:** Docker needs at least **4 GB of memory**. On Docker Desktop go to *Settings → Resources → Memory* and increase it if needed. 6 GB recommended if you plan to run all levels at once.

## Usage

### 1. Init

```bash
cd terraform
terraform init
```

### 2. Apply

```bash
terraform apply
```

### 3. Set KUBECONFIG

Write the kubeconfig to a local file and point `KUBECONFIG` to it:

```bash
terraform output -raw kubeconfig > kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
```

> The `kubeconfig` file is git-ignored. Run this step once per cluster — the path stays stable across applies.

### 4. Get the ArgoCD admin password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

> **Note:** ArgoCD deletes this secret once you change the password via the UI.

### 5. Open ArgoCD

Start the port-forward:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

Then open [http://localhost:8080](http://localhost:8080) in your browser.

**Credentials:**
- Username: `admin`
- Password: output from step 4

## Levels

The `argocd/` directory is structured as a progression of levels, each introducing a new GitOps concept. Make sure the cluster is up and ArgoCD is accessible before starting.

> **Levels 2 and 3 pull manifests from Git.** The Applications point to this public repository by default — no extra setup needed, just apply and go.
>
> **Want to push your own changes and watch ArgoCD sync them?** Fork the repo and run the setup script to point the Applications to your fork:
> ```bash
> ./setup.sh <your-github-username>
> git add .
> git commit -m "chore: set repoURL to my fork"
> git push
> ```
> Once an Application is applied, every subsequent change you push will be picked up by ArgoCD automatically. The first `kubectl apply` is always required to register the Application with ArgoCD.
>
> **Using a private fork?** You need to add the repository to ArgoCD first. See the [official docs](https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/).

---

### Level 1 — Helm chart source

Deploy [KubeView](https://github.com/benc-uk/kubeview), a cluster visualizer, directly from a Helm chart repository. This is the simplest ArgoCD use case: point to a chart, let ArgoCD handle the rest.

```bash
kubectl apply -f argocd/level-1/kubeview.yaml
```

Once synced, access it:

```bash
kubectl -n kubeview port-forward svc/kubeview 8081:8000
```

Open [http://localhost:8081](http://localhost:8081).

---

### Level 2 — Raw Kubernetes manifests

Deploy an echo server ([traefik/whoami](https://github.com/traefik/whoami)) from plain Kubernetes manifests stored in this repo. ArgoCD watches the `argocd/level-2/manifests/` directory and applies whatever is there.

```bash
kubectl apply -f argocd/level-2/echo-server.yaml
```

Once synced, access it:

```bash
kubectl -n echo-server port-forward svc/echo-server 8082:80
```

```bash
curl http://localhost:8082
```

> **Try it — GitOps sync:** edit `argocd/level-2/manifests/deployment.yaml`, change `replicas` to `2`, push to GitHub, and watch ArgoCD sync the change automatically.

> **Try it — self-healing:** manually force a drift by scaling the deployment down to `0` with kubectl, then watch ArgoCD detect and fix it:
> ```bash
> # Force a drift
> kubectl -n echo-server scale deployment echo-server --replicas=0
>
> # Watch ArgoCD reconcile it back
> kubectl -n echo-server get pods -w
> ```
> Within seconds ArgoCD will detect that the live state diverged from the desired state in Git and restore the replicas. This is the reconciliation loop in action.

---

### Level 3 — Kustomize overlays

Deploy the same application to two different environments (`dev` and `prod`) from a single base using [Kustomize](https://kustomize.io/). Each overlay customizes the base without duplicating it — a common real-world GitOps pattern.

| | dev | prod |
|---|---|---|
| Namespace | `echo-server-dev` | `echo-server-prod` |
| Replicas | 1 | 3 |
| Label | `env: dev` | `env: prod` |

```bash
kubectl apply -f argocd/level-3/dev.yaml
kubectl apply -f argocd/level-3/prod.yaml
```

Once synced, access each environment on a different port:

```bash
# dev
kubectl -n echo-server-dev port-forward svc/echo-server 8083:80

# prod (new terminal)
kubectl -n echo-server-prod port-forward svc/echo-server 8084:80
```

> **Try it:** edit `overlays/prod/kustomization.yaml`, change `replicas` to `5`, push to GitHub, and watch only the prod Application sync while dev stays unchanged.

---

### Level 4 — Infrastructure managed by ArgoCD

GitOps is not only for applications — infrastructure components can and should be managed the same way. In this level ArgoCD deploys [KEDA](https://keda.sh) (Kubernetes Event-Driven Autoscaling), a CNCF Graduated project that extends Kubernetes with event-driven autoscaling capabilities. Installing it via ArgoCD means the cluster's capabilities are themselves version-controlled and reconciled from Git.

```bash
kubectl apply -f argocd/level-4/keda.yaml
```

Once synced, verify KEDA is running:

```bash
kubectl -n keda get pods
```

KEDA installs its CRDs into the cluster (`ScaledObject`, `ScaledJob`, `TriggerAuthentication`). You can now define autoscaling rules declaratively alongside your application manifests.

## Destroy

```bash
terraform destroy
```

This removes the kind cluster and all its containers. The local `terraform.tfstate` file will remain.

