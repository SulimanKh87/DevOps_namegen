# Random Name Generator & Saver – DevOps on AWS EKS (Auto Mode)

[![CI/CD](https://github.com/SulimanKh87/DevOps_namegen/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/SulimanKh87/DevOps_namegen/actions/workflows/ci-cd.yml)

A simple Node.js + MongoDB app deployed the “DevOps way”:
- Containerized with Docker
- Deployed to **Amazon EKS (Auto Mode)** with Kubernetes manifests
- Images stored in **Amazon ECR**
- **MongoDB** runs in-cluster as a **StatefulSet + PersistentVolume**
- Exposed via **NLB (LoadBalancer)** Service
- CI/CD via **GitHub Actions**
- Optional monitoring via **Prometheus + Grafana** (Helm)

## 📦 Repo structure

.
├── Dockerfile
├── .dockerignore
├── server.js / index.js / schemas.js / package.json # app source
├── eksctl/cluster.yaml # EKS Auto Mode spec (eu-central-1)
├── k8s/
│ ├── namespace.yaml
│ ├── storageclass-gp3.yaml # default gp3 StorageClass (Auto Mode CSI)
│ ├── mongodb-init-configmap.yaml
│ ├── mongodb-service.yaml
│ ├── mongodb-statefulset.yaml
│ ├── app-deployment.yaml
│ └── app-service.yaml
├── .github/workflows/ci-cd.yml # build to ECR + deploy to EKS
├── diagrams/architecture.drawio
└── docs/screenshots/ # screenshots for submission

## ✅ Assignment mapping

- [x] **EKS (Auto Mode)** via `eksctl/cluster.yaml`
- [x] **CI/CD** with GitHub Actions → build & push to ECR + `kubectl apply`
- [x] **Expose with LoadBalancer (NLB)** → `k8s/app-service.yaml`
- [x] **MongoDB StatefulSet + PVs** → `k8s/mongodb-statefulset.yaml` (+ gp3 StorageClass)
- [x] **Terraform/eksctl** → using **eksctl** (as allowed)
- [x] **Prometheus + Grafana** → provided Helm steps (optional to install)
- [x] **Env var** `MONGODB_URL` supported
- [x] **Diagram** in `diagrams/architecture.drawio`
- [x] **README** (this file)
- [x] **Screenshots** to be added to `docs/screenshots/`

## 🧰 Prerequisites

- Docker Desktop (with Kubernetes context available)
- AWS account, **AWS CLI** logged in (`aws sts get-caller-identity`)
- `kubectl`, `helm`, `eksctl ≥ 0.195`
- An ECR repository (e.g. `namegen`)
- GitHub repository (this repo)

## 🚀 Build & push image to Amazon ECR

```bash
export AWS_REGION=eu-central-1
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
REPO=namegen
IMAGE="$ECR/$REPO:latest"

# Create repo if needed
aws ecr describe-repositories --repository-names "$REPO" --region "$AWS_REGION" >/dev/null 2>&1 || \
aws ecr create-repository --repository-name "$REPO" --region "$AWS_REGION" \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256

# Login, build and push
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR"
docker build -t "$IMAGE" .
docker push "$IMAGE"
☁️ Create EKS cluster (Auto Mode) with eksctl
bash
Copy
Edit
# Create cluster (one-time). Adjust eksctl/cluster.yaml if needed.
eksctl create cluster -f eksctl/cluster.yaml

# Point kubectl to it
aws eks update-kubeconfig --region eu-central-1 --name namegen-auto
kubectl get nodes -o wide
🧱 Storage class (gp3) – Auto Mode CSI

```bash
kubectl apply -f k8s/storageclass-gp3.yaml
kubectl get storageclass
# expect: eks-gp3 (default)  ebs.csi.eks.amazonaws.com  ...
🔐 Secrets & config
Create .env locally (git-ignored):

# Never commit this file
MONGODB_URL=mongodb://genuser:<password>@mongodb
DB_NAME=namegen
SERVER_PORT=8080
Create a Kubernetes Secret from .env:

```bash
kubectl create ns namegen || true
kubectl -n namegen delete secret app-env --ignore-not-found
kubectl -n namegen create secret generic app-env --from-env-file=.env
📦 Deploy MongoDB + app

```bash
# MongoDB
kubectl -n namegen apply -f k8s/mongodb-init-configmap.yaml
kubectl -n namegen apply -f k8s/mongodb-service.yaml
kubectl -n namegen apply -f k8s/mongodb-statefulset.yaml
kubectl -n namegen rollout status sts/mongodb --timeout=600s

# App (uses Secret envs)
kubectl -n namegen apply -f k8s/app-deployment.yaml

# Point the Deployment to the ECR image you built
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR="$ACCOUNT_ID.dkr.ecr.eu-central-1.amazonaws.com"
kubectl -n namegen set image deploy/namegen-app app="$ECR/namegen:latest"

kubectl -n namegen rollout status deploy/namegen-app --timeout=600s
kubectl -n namegen get pods -o wide
Expose via NLB and get the public DNS:

bash
Copy
Edit
kubectl -n namegen apply -f k8s/app-service.yaml

EXT=""
while [ -z "$EXT" ]; do
  EXT=$(kubectl -n namegen get svc namegen-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null); echo "Waiting for NLB..."; sleep 10;
done
echo "LB: http://$EXT"
Test:

```bash
curl "http://$EXT/api/connection"
curl -X POST "http://$EXT/api/names" -H "Content-Type: application/json" -d '{"firstName":"Ada","lastName":"Lovelace"}'
curl "http://$EXT/api/names"
Local port-forward (optional):

```bash
kubectl -n namegen port-forward deploy/namegen-app 8080:8080
curl http://localhost:8080/api/connection
📈 Monitoring (optional but recommended)
Install Prometheus + Grafana (Helm):

```bash
kubectl create ns monitoring || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install stack (no credentials printed)
helm upgrade --install kube-prom-stack prometheus-community/kube-prometheus-stack -n monitoring

# Get Grafana password
kubectl -n monitoring get secret kube-prom-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo

# Access Grafana locally
kubectl -n monitoring port-forward svc/kube-prom-stack-grafana 3000:80
# open http://localhost:3000  (user: admin, password: from previous command)
Add screenshots to docs/screenshots/:

kubectl get pods -n namegen

Browser or curl output for /api/connection and /api/names

Grafana home/dashboard page

🔄 CI/CD (GitHub Actions)
Set Actions Secrets (Repo → Settings → Secrets and variables → Actions):

AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY

AWS_REGION=eu-central-1

ECR_REPOSITORY=namegen

EKS_CLUSTER_NAME=namegen-auto

K8S_NAMESPACE=namegen

Workflow: .github/workflows/ci-cd.yml

On push: build Docker → push to ECR → kubectl apply → kubectl set image.

🧯 Troubleshooting
PVC Pending: first node + EBS volume are provisioning. Wait, then check:

kubectl -n namegen describe pvc
kubectl get nodes -o wide
ImagePullBackOff: image not found in ECR or wrong tag. Verify:


kubectl -n namegen get deploy namegen-app -o=jsonpath='{.spec.template.spec.containers[0].image}'; echo
CrashLoopBackOff: envs/secrets. Recreate Secret from .env and restart:


kubectl -n namegen delete secret app-env --ignore-not-found
kubectl -n namegen create secret generic app-env --from-env-file=.env
kubectl -n namegen rollout restart deploy/namegen-app
NLB DNS empty: give it 1–3 minutes; check events:

```bash
kubectl -n namegen get svc namegen-service -o wide
kubectl get events --sort-by=.lastTimestamp | tail -n 50

📜 License
MI
