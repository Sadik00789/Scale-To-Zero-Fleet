
# ⚡ Scale-To-Zero Fleet

> **Ephemeral, Cost-Optimized GitHub Actions Runner Fleet on AWS EKS powered by Karpenter & Actions Runner Controller (ARC)**

[![Terraform](https://img.shields.io/badge/Terraform-%253E%3D%201.5.0-623CE4?style=flat&logo=terraform)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.34-326CE5?style=flat&logo=kubernetes)](https://kubernetes.io/)
[![AWS EKS](https://img.shields.io/badge/AWS-EKS-FF9900?style=flat&logo=amazon-aws)](https://aws.amazon.com/eks/)
[![Karpenter](https://img.shields.io/badge/Karpenter-v1.0.1-232F3E?style=flat&logo=amazoneks)](https://karpenter.sh/)
[![ARC](https://img.shields.io/badge/GitHub-Actions_Runner_Controller-181717?style=flat&logo=github)](https://github.com/actions/actions-runner-controller)

---

## 📌 Architecture & Overview

`Scale-To-Zero Fleet` is a cloud-native infrastructure blueprint designed to run self-hosted GitHub Actions runners with **zero idle compute cost**. 

By pairing **Actions Runner Controller (ARC)** for pod-level auto-scaling with **Karpenter** for just-in-time EC2 Spot instance provisioning, the cluster dynamically provisions high-compute worker nodes only when CI/CD jobs are queued, and completely teardowns nodes 30 seconds after jobs finish.

```
                  +-----------------------------------+
                  |   GitHub Actions Workflow Trigger |
                  +-----------------------------------+
                                    |
                                    v
                 +--------------------------------------+
                 | Actions Runner Controller (ARC)      |
                 | Scales Runner Pods (min: 0, max: 5)  |
                 +--------------------------------------+
                                    |
                                    v
                 +--------------------------------------+
                 | Pending Pod (CPU: 1.5, Memory: 2Gi)  |
                 +--------------------------------------+
                                    |
                                    v
                 +--------------------------------------+
                 | Karpenter Controller (IRSA)          |
                 | Evaluates Unschedulable Pod          |
                 +--------------------------------------+
                                    |
                                    v
                 +--------------------------------------+
                 | Provisions EC2 Spot Instance         |
                 | (c5/c6/m5/m6/t3 Spot Families)       |
                 +--------------------------------------+
                                    |
                                    v
                 +--------------------------------------+
                 | Job Completes -> Pod Terminated      |
                 | Karpenter Consolidates Empty Node    |
                 | (Terminates Spot EC2 in 30s)         |
                 +--------------------------------------+
```

---

## 🚀 Key Features & Cost Optimizations

* **True Scale-To-Zero Cost Structure**: Runner pods scale down to `minRunners: 0`. When no CI jobs run, zero EC2 Spot runner nodes exist.
* **Rapid Karpenter Node Provisioning**: Direct EC2 fleet integration bypasses Kubernetes Auto Scaler (CAS) node group lag, provisioning EC2 Spot instances in under a minute.
* **Aggressive Node Consolidation**: `consolidationPolicy: WhenEmpty` with `consolidateAfter: 30s` guarantees unused Spot nodes are terminated promptly.
* **EC2 Spot Diversification**: Configured to match `c`, `m`, and `t` instance families across `5`th and `6`th generations, ensuring maximum Spot availability and up to 90% cost savings over On-Demand.
* **Single NAT Gateway Architecture**: Saves ~$0.09/hour (~$65/month) compared to standard multi-AZ NAT topologies while retaining private subnet security for nodes.
* **IRSA (IAM Roles for Service Accounts)**: Karpenter Controller authenticates securely via AWS OIDC without static IAM credentials.

---

## 📂 Repository Structure

```
Scale-To-Zero-Fleet/
├── terraform/
│   ├── main.tf                 # VPC, EKS Cluster, IRSA Roles, and Karpenter Helm Release
│   ├── variables.tf            # AWS Region, Cluster Name, and Kubernetes Version definitions
│   └── outputs.tf              # Cluster metadata, Node IAM role names & kubeconfig command
├── k8s/
│   ├── karpenter-nodepool.yaml # Karpenter NodePool & EC2NodeClass (Spot rules & 30s consolidation)
│   └── arc-runner-values.yaml  # Helm values for ARC AutoscalingRunnerSet (minRunners: 0)
├── .github/
│   └── workflows/
│       └── ci-test.yml         # Verification workflow targeting `scale-to-zero-runner`
├── .gitignore                  # Git ignore rules for Terraform local state, OS & editor files
└── README.md                   # Project documentation
```

---

## 🛠️ Prerequisites

Ensure you have the following CLI tools installed and configured:

1. [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with adequate permissions (`aws configure`).
2. [Terraform](https://developer.hashicorp.com/terraform/downloads) (`>= 1.5.0`).
3. [kubectl](https://kubernetes.io/docs/tasks/tools/) matching your cluster Kubernetes version (`1.34`).
4. [Helm](https://helm.sh/docs/intro/install/) (`>= v3.0`).
5. A **GitHub Personal Access Token (PAT)** with `repo` scope (or GitHub App credentials) to register ARC runners.

---

## 📖 Deployment Guide

### Step 1: Provision Infrastructure with Terraform

Initialize and apply the Terraform configuration to provision the VPC, EKS cluster, managed system node group, IAM roles, and the Karpenter Helm release:

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

### Step 2: Configure Local `kubectl` Context

Connect to your newly created EKS cluster:

```bash
aws eks update-kubeconfig --region us-east-2 --name scale-to-zero-eks
```

Verify the system node group is running:

```bash
kubectl get nodes -l role=system
```

### Step 3: Apply Karpenter NodePool & EC2NodeClass

1. Retrieve the IAM Role created for dynamic Karpenter nodes from Terraform outputs:

   ```bash
   terraform output karpenter_node_role_name
   ```

2. Open [`k8s/karpenter-nodepool.yaml`](file:///c:/Users/Sadik/Downloads/Scale-To-Zero-Fleet/k8s/karpenter-nodepool.yaml) and replace the placeholder `role:` field in `EC2NodeClass` with your actual IAM role name.

3. Apply the spec to your cluster:

   ```bash
   kubectl apply -f ../k8s/karpenter-nodepool.yaml
   ```

### Step 4: Deploy Actions Runner Controller (ARC) Runner Set

1. Create a namespace and GitHub PAT secret for ARC:

   ```bash
   kubectl create namespace arc-runners
   kubectl create secret generic github-token-secret \
     --namespace arc-runners \
     --from-literal=github_token="YOUR_GITHUB_PERSONAL_ACCESS_TOKEN"
   ```

2. Deploy the ARC Runner Scale Set via Helm using [`k8s/arc-runner-values.yaml`](file:///c:/Users/Sadik/Downloads/Scale-To-Zero-Fleet/k8s/arc-runner-values.yaml):

   ```bash
   helm install arc-runner-set oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
     --namespace arc-runners \
     -f ../k8s/arc-runner-values.yaml
   ```

3. Confirm that zero runner pods are running (`minRunners: 0`):

   ```bash
   kubectl get pods -n arc-runners
   ```

---

## 🧪 Testing Scale-To-Zero Execution

1. Navigate to your repository's **Actions** tab on GitHub or dispatch [`ci-test.yml`](file:///c:/Users/Sadik/Downloads/Scale-To-Zero-Fleet/.github/workflows/ci-test.yml) manually.
2. Watch ARC scale up a runner pod in real-time:
   ```bash
   kubectl get pods -n arc-runners -w
   ```
3. Watch Karpenter provision an EC2 Spot instance automatically:
   ```bash
   kubectl get nodes -l role=github-runner -w
   ```
4. Once the job completes, observe the runner pod terminate and Karpenter delete the EC2 Spot node 30 seconds later (`consolidateAfter: 30s`).

---

## 🧹 Teardown / Cleanup

To avoid unexpected cloud charges, tear down the environment in reverse order:

```bash
# 1. Remove ARC Runner Scale Set
helm uninstall arc-runner-set -n arc-runners
kubectl delete namespace arc-runners

# 2. Remove Karpenter NodePool resources
kubectl delete -f k8s/karpenter-nodepool.yaml

# 3. Destroy Terraform Infrastructure
cd terraform
terraform destroy -auto-approve
```

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

<img width="1920" height="1080" alt="Screenshot 2026-08-12 174430" src="https://github.com/user-attachments/assets/35136aa5-70d9-4616-b923-ec07cf36fe10" />
<img width="1920" height="1080" alt="Screenshot 2026-08-12 174444" src="https://github.com/user-attachments/assets/478c25ff-0264-4eb4-83eb-664bc0ac2210" />
<img width="1920" height="1080" alt="Screenshot 2026-08-12 174452" src="https://github.com/user-attachments/assets/a19ed805-230c-4c7c-8c96-a8f2a38aa3d4" />
<img width="1920" height="1080" alt="Screenshot 2026-08-12 174458" src="https://github.com/user-attachments/assets/ec564ccd-fd7e-4263-8ea9-b32a0037adec" />
