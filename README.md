# tp-final
tp final
# 🛡️ Projet Final – Chaîne DevSecOps complète pour Online Boutique

## 📌 Contexte
Ce projet met en place une **chaîne DevSecOps de bout en bout** pour l'application e-commerce [Online Boutique (Google Microservices Demo)](https://github.com/GoogleCloudPlatform/microservices-demo).  
L’objectif est de **déployer en cloud local** l’application composée de 12 microservices tout en intégrant des **contrôles de sécurité à chaque étape**.

## 🚀 Objectifs principaux
1. **Pipeline CI/CD sécurisé**
   - Intégration continue avec **analyses SAST/SCA/Secrets**
   - Génération de **SBOM** et signature des images conteneurs
   - Scan de vulnérabilités automatiques avant déploiement

2. **Orchestration & Déploiement**
   - Cluster Kubernetes local (**k3s**)
   - Déploiement via **Helm/Kustomize**
   - Automatisation infra avec **Ansible**
   - Sécurité K8s : RBAC, NetworkPolicies, Kyverno/Gatekeeper, Pod Security Admission

3. **Surveillance & Détection**
   - Monitoring avec **Prometheus/Grafana**
   - Centralisation des logs avec **Loki + Promtail**
   - Détection d’intrusion avec **Falco** (Kubernetes) et **Wazuh** (EDR/SIEM)
   - Tests de sécurité dynamiques (DAST, kube-bench, kube-hunter)

## 🏗️ Architecture cible
- **Infrastructure locale**
  - Kubernetes (k3s)
  - Registre privé **Harbor** avec scan intégré
  - GitLab/GitHub pour CI/CD
- **Outils DevSecOps**
  - SAST/SCA : Semgrep, Trivy, Gitleaks, Checkov
  - CI/CD : GitLab CI (ou GitHub Actions)
  - Observabilité : Prometheus, Grafana, Loki
  - Sécurité runtime : Falco + Wazuh
  - Supply chain : Cosign (signatures), Syft (SBOM)

## 📂 Arborescence du dépôt
