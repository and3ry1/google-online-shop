# Script pour améliorer la résilience des microservices

param(
    [string]$Action = "help",
    [int]$Replicas = 3
)

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Scale-CriticalServices {
    param([int]$Replicas = 3)
    
    Write-Info "🛡️ Amélioration de la résilience avec $Replicas répliques par service"
    
    # Services critiques qui nécessitent haute disponibilité
    $criticalServices = @(
        "frontend",
        "cartservice", 
        "productcatalogservice",
        "currencyservice",
        "checkoutservice",
        "paymentservice"
    )
    
    foreach ($service in $criticalServices) {
        Write-Info "📈 Mise à l'échelle de $service vers $Replicas répliques..."
        try {
            kubectl scale deployment $service --replicas=$Replicas
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✅ $service mis à l'échelle avec succès"
            } else {
                Write-Warning "❌ Erreur lors de la mise à l'échelle de $service"
            }
        } catch {
            Write-Warning "❌ Exception lors de la mise à l'échelle de $service : $_"
        }
    }
    
    # Services moins critiques - 2 répliques
    $standardServices = @(
        "adservice",
        "emailservice", 
        "recommendationservice",
        "shippingservice"
    )
    
    foreach ($service in $standardServices) {
        Write-Info "📊 Mise à l'échelle de $service vers 2 répliques..."
        try {
            kubectl scale deployment $service --replicas=2
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✅ $service mis à l'échelle avec succès"
            }
        } catch {
            Write-Warning "❌ Exception lors de la mise à l'échelle de $service : $_"
        }
    }
    
    # Redis reste à 1 réplique (stateful)
    Write-Info "🗄️ Redis-cart maintenu à 1 réplique (base de données)"
}

function Add-HealthChecks {
    Write-Info "🏥 Configuration des contrôles de santé avancés..."
    
    # Exemple pour le frontend
    $frontendPatch = @'
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "server",
            "livenessProbe": {
              "httpGet": {
                "path": "/_healthz",
                "port": 8080
              },
              "initialDelaySeconds": 10,
              "periodSeconds": 10,
              "timeoutSeconds": 5,
              "failureThreshold": 3
            },
            "readinessProbe": {
              "httpGet": {
                "path": "/_healthz",
                "port": 8080
              },
              "initialDelaySeconds": 5,
              "periodSeconds": 5,
              "timeoutSeconds": 3,
              "failureThreshold": 2
            }
          }
        ]
      }
    }
  }
}
'@
    
    try {
        $frontendPatch | kubectl patch deployment frontend --patch-file=/dev/stdin
        Write-Success "✅ Health checks ajoutés au frontend"
    } catch {
        Write-Warning "⚠️ Health checks non appliqués (peut nécessiter des ajustements)"
    }
}

function Test-Resilience {
    Write-Info "🧪 TEST DE RÉSILIENCE"
    Write-Info "====================="
    
    # 1. Tester la panne d'un service critique
    Write-Info "1️⃣ Test de panne du cartservice..."
    $cartPod = kubectl get pods -l app=cartservice -o jsonpath='{.items[0].metadata.name}'
    
    Write-Info "🔥 Simulation de panne : suppression du pod $cartPod"
    kubectl delete pod $cartPod
    
    # 2. Vérifier que le site reste accessible
    Write-Info "2️⃣ Vérification de l'accessibilité du site..."
    Start-Sleep -Seconds 2
    
    for ($i = 1; $i -le 5; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 5 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Success "✅ Tentative $i : Site accessible (HTTP $($response.StatusCode))"
            }
        } catch {
            Write-Warning "❌ Tentative $i : Site non accessible"
        }
        Start-Sleep -Seconds 2
    }
    
    # 3. Vérifier la récupération automatique
    Write-Info "3️⃣ Vérification de la récupération automatique..."
    Start-Sleep -Seconds 10
    
    $newPods = kubectl get pods -l app=cartservice --field-selector=status.phase=Running
    if ($newPods) {
        Write-Success "✅ Cartservice récupéré automatiquement"
        kubectl get pods -l app=cartservice
    } else {
        Write-Warning "❌ Problème de récupération du cartservice"
    }
}

function Show-ResilienceStatus {
    Write-Info "📊 ÉTAT DE LA RÉSILIENCE"
    Write-Info "========================"
    
    # Nombre de répliques par service
    Write-Host "`n🔢 Répliques par service :" -ForegroundColor White
    kubectl get deployments -o custom-columns="SERVICE:.metadata.name,READY:.status.readyReplicas,DESIRED:.spec.replicas,UP-TO-DATE:.status.updatedReplicas"
    
    # Services avec une seule réplique (risque)
    Write-Host "`n⚠️ Services à risque (1 seule réplique) :" -ForegroundColor Yellow
    $singleReplicas = kubectl get deployments -o json | ConvertFrom-Json | Select-Object -ExpandProperty items | Where-Object { $_.spec.replicas -eq 1 }
    if ($singleReplicas) {
        $singleReplicas | ForEach-Object { Write-Host "   - $($_.metadata.name)" -ForegroundColor Red }
    } else {
        Write-Host "   Aucun (Excellent !)" -ForegroundColor Green
    }
    
    # Pods en cours d'exécution
    Write-Host "`n🟢 Pods en cours d'exécution :" -ForegroundColor White
    $runningPods = kubectl get pods --field-selector=status.phase=Running --no-headers | Measure-Object
    $totalPods = kubectl get pods --no-headers | Measure-Object
    Write-Host "   $($runningPods.Count)/$($totalPods.Count) pods opérationnels" -ForegroundColor Green
}

function Create-ResiliencePlaybook {
    Write-Info "📝 Création d'un playbook Ansible pour la résilience..."
    
    $resiliencePlaybook = @'
---
- name: Improve Microservices Resilience
  hosts: localhost
  connection: local
  gather_facts: false
  
  vars:
    namespace: default
    critical_services:
      - name: frontend
        replicas: 3
      - name: cartservice
        replicas: 3
      - name: productcatalogservice
        replicas: 3
      - name: currencyservice
        replicas: 3
      - name: checkoutservice
        replicas: 3
      - name: paymentservice
        replicas: 3
    
    standard_services:
      - name: adservice
        replicas: 2
      - name: emailservice
        replicas: 2
      - name: recommendationservice
        replicas: 2
      - name: shippingservice
        replicas: 2
  
  tasks:
    - name: Scale critical services for high availability
      kubernetes.core.k8s_scale:
        api_version: apps/v1
        kind: Deployment
        name: "{{ item.name }}"
        namespace: "{{ namespace }}"
        replicas: "{{ item.replicas }}"
      loop: "{{ critical_services }}"
      
    - name: Scale standard services for resilience
      kubernetes.core.k8s_scale:
        api_version: apps/v1
        kind: Deployment
        name: "{{ item.name }}"
        namespace: "{{ namespace }}"
        replicas: "{{ item.replicas }}"
      loop: "{{ standard_services }}"
      
    - name: Wait for all deployments to be ready
      kubernetes.core.k8s_info:
        api_version: apps/v1
        kind: Deployment
        name: "{{ item.name }}"
        namespace: "{{ namespace }}"
        wait: true
        wait_condition:
          type: Progressing
          status: "True"
          reason: NewReplicaSetAvailable
        wait_timeout: 300
      loop: "{{ (critical_services + standard_services) | map(attribute='name') | list }}"
'@
    
    $resiliencePlaybook | Out-File -FilePath "playbooks\improve-resilience.yml" -Encoding UTF8
    Write-Success "✅ Playbook de résilience créé : playbooks\improve-resilience.yml"
}

# Logique principale
switch ($Action.ToLower()) {
    "scale" {
        Scale-CriticalServices -Replicas $Replicas
        Show-ResilienceStatus
    }
    "health" {
        Add-HealthChecks
    }
    "test" {
        Test-Resilience
    }
    "status" {
        Show-ResilienceStatus
    }
    "playbook" {
        Create-ResiliencePlaybook
    }
    "full" {
        Write-Info "🚀 AMÉLIORATION COMPLÈTE DE LA RÉSILIENCE"
        Write-Info "=========================================="
        Scale-CriticalServices -Replicas $Replicas
        Add-HealthChecks
        Create-ResiliencePlaybook
        Show-ResilienceStatus
        Write-Success "🎉 Résilience améliorée avec succès !"
    }
    "help" {
        Write-Host @"
🛡️ AMÉLIORATEUR DE RÉSILIENCE - MICROSERVICES

Usage: .\Improve-Resilience.ps1 -Action <action> [-Replicas <number>]

Actions:
  scale      Augmenter le nombre de répliques des services critiques
  health     Ajouter des contrôles de santé avancés
  test       Tester la résilience avec simulation de panne
  status     Afficher l'état actuel de la résilience
  playbook   Créer un playbook Ansible pour la résilience
  full       Amélioration complète (recommandé)
  help       Afficher cette aide

Options:
  -Replicas <n>   Nombre de répliques pour les services critiques (défaut: 3)

Exemples:
  .\Improve-Resilience.ps1 -Action full
  .\Improve-Resilience.ps1 -Action scale -Replicas 5
  .\Improve-Resilience.ps1 -Action test

🎯 Pour une amélioration complète : -Action full
"@ -ForegroundColor White
    }
    default {
        Write-Warning "Action non reconnue: $Action"
        Write-Host "Utilisez -Action help pour voir les options disponibles" -ForegroundColor Gray
    }
}
