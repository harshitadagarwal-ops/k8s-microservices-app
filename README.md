# K8s Microservices — Demo Runbook

A 3-tier demo app for teaching **Deploying Microservices on Kubernetes** to beginners.

```
Browser ──> frontend (Flask, NodePort) ──> backend (Flask REST API) ──> mysql (MySQL, emptyDir)
```

- **frontend/** — Flask web UI (port 8080), calls the backend by Service name
- **backend/** — Flask REST API (port 5000), reads/writes MySQL
- **manifests/** — Kubernetes YAML (Namespace, ConfigMap, Secret, Deployments, Services)
- **CONTENT.md** — full teaching script / speaker notes

> ⚠️ MySQL uses `emptyDir` (temporary storage). Data is lost when the pod restarts.
> This is intentional for a beginner demo. Never do this in production.

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (used as Minikube's driver)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

Verify:
```bash
docker version
minikube version
kubectl version --client
```

---

## Step-by-step demo

### 1. Start Minikube
```bash
minikube start
kubectl get nodes          # should show "minikube  Ready"
```

### 2. Build the images INSIDE Minikube
Minikube has its own Docker daemon. Point your shell at it so the images are
available to the cluster without pushing to a registry.

**Linux / macOS:**
```bash
eval $(minikube docker-env)
```

**Windows PowerShell:**
```powershell
& minikube -p minikube docker-env --shell powershell | Invoke-Expression
```

Then build:
```bash
docker build -t backend:latest ./backend
docker build -t frontend:latest ./frontend
```

### 3. Deploy everything
```bash
kubectl apply -f manifests/
```

### 4. Watch it come up
```bash
kubectl get pods -n demo -w
# Wait until all pods are Running / READY 1/1  (MySQL takes ~30-60s the first time)
```

```bash
kubectl get svc -n demo
```

### 5. Open the app
```bash
minikube service frontend -n demo
```
This opens the frontend in your browser. Add a message; it's saved in MySQL via the backend.

---

## Live teaching moments

**Self-healing** — delete a pod and watch the Deployment recreate it:
```bash
kubectl get pods -n demo
kubectl delete pod <a-backend-pod-name> -n demo
kubectl get pods -n demo        # a new one is already being created
```

**Scaling** — change the number of replicas on the fly:
```bash
kubectl scale deployment backend --replicas=4 -n demo
kubectl get pods -n demo        # now 4 backend pods
```

**Inspecting** — useful for debugging:
```bash
kubectl describe deployment backend -n demo
kubectl logs deploy/backend -n demo
kubectl get all -n demo
```

**Dashboard (visual):**
```bash
minikube dashboard
```

---

## Cleanup
```bash
kubectl delete -f manifests/        # remove the app
minikube stop                       # stop the cluster (keeps it)
minikube delete                     # delete the cluster entirely
```

---

## Alternatives to Minikube (mentioned in class)

| Tool | What it is | Best for |
|------|-----------|----------|
| Minikube | Single-node local cluster | Learning / local dev (this demo) |
| kind | Kubernetes in Docker | CI, throwaway clusters |
| k3s | Lightweight Kubernetes | Edge / IoT / low-resource |
| Docker Desktop | Built-in K8s toggle | Docker Desktop users |
| EKS / GKE / AKS | Managed cloud Kubernetes | Production |
