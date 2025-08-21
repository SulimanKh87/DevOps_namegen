# Random Name Generator & Saver — DevOps Project 

**Includes EKS (eksctl Auto Mode), CI/CD (GitHub Actions), NLB, MongoDB StatefulSet + PV, Prometheus+Grafana setup, README, diagram, K8s manifests, and app source.**

See steps inside:
- Create cluster: `eksctl create cluster -f eksctl/cluster.yaml`
- Install monitoring via Helm (Prometheus+Grafana)
- Build/push image to ECR, then apply manifests (Mongo → App → Service)
- Test with the NLB hostname
- CI/CD with OIDC role + `AWS_OIDC_ROLE_ARN` repo secret
