# 🚀 Infrastructure Automation - Terraform + Ansible

## 🎯 Description

Automatisation complète du déploiement des microservices Online Boutique avec :

- **Terraform** pour l'Infrastructure as Code
- **Ansible** pour le déploiement automatisé
- **PowerShell** pour l'orchestration et la gestion

## ✅ Fonctionnalités

### 🔧 Déploiement Automatisé
- 11 microservices déployés automatiquement
- Gestion séparée par service (mises à jour indépendantes)
- Stratégies de déploiement par criticité

### 🛡️ Résilience et Monitoring
- Réplication adaptée par service (1-3 répliques)
- Auto-healing et rollbacks granulaires
- Surveillance continue de la santé

### 🌐 Accès Web
- Interface Online Boutique accessible
- Port-forward automatique
- Configuration réseau complète

### 🎯 Scripts de Production (5)
- **Deploy-Microservices.ps1** - Déploiement principal des 11 microservices
- **Separate-Services-Manager.ps1** - Gestion séparée et mises à jour par service
- **WebAccess-Manager.ps1** - Gestion automatique de l'accès web
- **Monitor-Health.ps1** - Surveillance continue et auto-healing
- **Improve-Resilience.ps1** - Amélioration de la résilience et scaling

### 📊 Monitoring Infrastructure (Séparé)
- **Dossier dédié** : `../monitoring-infrastructure/`
- **Stack complète** : Prometheus + Grafana + Jaeger + AlertManager
- **Isolation** : Environment complètement séparé pour la sécurité

## 🚀 Quick Start

### Prérequis
- Docker Desktop + Kubernetes enabled
- kubectl configuré
- PowerShell 5.1+
- Ansible + collections kubernetes.core

### Déploiement Rapide
```powershell
# 1. Cloner le repository
git clone <repository-url>
cd infrastructure-automation

# 2. Déployer l'infrastructure
cd terraform
terraform init && terraform apply

# 3. Déployer les microservices
cd ../ansible
.\Deploy-Microservices.ps1 -Action deploy-all

# 4. Accéder à l'application
.\WebAccess-Manager.ps1 -Action setup
```

### 📊 **Phase 3: Monitoring (🆕 ISOLÉ)**
```powershell
cd ../monitoring-infrastructure/ansible/
.\Deploy-Monitoring-Stack.ps1 -Action deploy-all

# Accès aux interfaces (environment séparé)
# Grafana: http://localhost:30030 (admin/admin123)
# Prometheus: http://localhost:30090
# Jaeger: http://localhost:30686
# AlertManager: http://localhost:30093
```

## 📊 Architecture

```
tp-final/
├── 🏭 infrastructure-automation-clean/  # Environment PRODUCTION
│   ├── 🔷 terraform/                   # Infrastructure as Code
│   ├── 🔧 ansible/                     # Déploiement microservices
│   │   ├── playbooks/                  # Playbooks Ansible
│   │   ├── templates/                  # Templates Kubernetes
│   │   └── *.ps1 (5 scripts)          # Scripts PowerShell production
│   ├── 🌐 .github/workflows/           # CI/CD GitHub Actions
│   └── 📚 docs/                       # Documentation
├── 📊 monitoring-infrastructure/        # Environment MONITORING (Isolé)
│   ├── 🔧 ansible/                     # Stack monitoring séparée
│   │   ├── playbooks/                  # Déploiement Prometheus/Grafana
│   │   ├── tasks/                      # Tâches de monitoring
│   │   └── Deploy-Monitoring-Stack.ps1 # Script principal monitoring
│   ├── 📊 dashboards/                  # Dashboards Grafana
│   ├── 🚨 alerts/                      # Règles d'alerte
│   └── 📚 docs/                       # Documentation monitoring
└── 🎯 microservices-demo/              # Source code (référence)
```

## 🎯 Commandes Principales

### Gestion Globale
```powershell
# Déploiement complet
.\Deploy-Microservices.ps1 -Action deploy-all

# Validation finale
.\Complete-Final-Validation.ps1

# Surveillance continue
.\Monitor-Health.ps1 -Action monitor
```

### Gestion Séparée (Recommandé)
```powershell
# Mise à jour d'un service
.\Separate-Services-Manager.ps1 -Action update -ServiceName frontend -Version v0.11.0

# Rollback granulaire
.\Separate-Services-Manager.ps1 -Action rollback -ServiceName cartservice

# Status par service
.\Separate-Services-Manager.ps1 -Action status
```

## 🏆 Avantages

| Aspect | Bénéfice |
|--------|----------|
| **Mises à jour** | Indépendantes par service (1-3 min vs 10-15 min) |
| **Résilience** | Rollbacks granulaires en 30 secondes |
| **Impact** | ~10% de l'application vs 100% |
| **Automatisation** | Déploiement sans intervention manuelle |
| **Monitoring** | Surveillance continue et auto-healing |

## 📚 Documentation

- [Rapport de Validation Final](docs/FINAL-VALIDATION-REPORT.md)
- [Guide de Déploiement](ansible/README.md)
- [Démonstration des Mises à Jour Séparées](ansible/Demo-Separate-Updates.ps1)

## 🎉 Statut

✅ **Production Ready** - Validé et opérationnel  
✅ **11/11 microservices** déployés  
✅ **Architecture microservices authentique**  
✅ **CI/CD intégré**  

---

**Dernière mise à jour :** Septembre 2025  
**Version :** 1.0.0  
**Statut :** ✅ PRODUCTION READY
