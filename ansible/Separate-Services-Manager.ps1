# Gestionnaire de déploiement séparé pour mises à jour indépendantes

param(
    [string]$Action = "help",
    [string]$ServiceName = "",
    [string]$Version = "v0.10.0",
    [string]$Strategy = "rolling"
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

# Configuration des services avec leurs spécificités
$services = @{
    "frontend" = @{
        "critical" = $true
        "dependencies" = @()
        "health_check" = "/_healthz"
        "port" = 8080
        "replicas" = 3
        "update_strategy" = "RollingUpdate"
        "max_unavailable" = "25%"
        "max_surge" = "25%"
    }
    "cartservice" = @{
        "critical" = $true
        "dependencies" = @("redis-cart")
        "health_check" = "/health"
        "port" = 7070
        "replicas" = 3
        "update_strategy" = "RollingUpdate"
        "max_unavailable" = "33%"
        "max_surge" = "33%"
    }
    "productcatalogservice" = @{
        "critical" = $true
        "dependencies" = @()
        "health_check" = "/health"
        "port" = 3550
        "replicas" = 3
        "update_strategy" = "RollingUpdate"
        "max_unavailable" = "33%"
        "max_surge" = "33%"
    }
    "checkoutservice" = @{
        "critical" = $true
        "dependencies" = @("cartservice", "currencyservice", "emailservice", "paymentservice", "shippingservice")
        "health_check" = "/health"
        "port" = 5050
        "replicas" = 3
        "update_strategy" = "RollingUpdate"
        "max_unavailable" = "33%"
        "max_surge" = "33%"
    }
    "currencyservice" = @{
        "critical" = $false
        "dependencies" = @()
        "health_check" = "/health"
        "port" = 7000
        "replicas" = 2
        "update_strategy" = "RollingUpdate"
        "max_unavailable" = "50%"
        "max_surge" = "50%"
    }
    "paymentservice" = @{
        "critical" = $true
        "dependencies" = @()
        "health_check" = "/health"
        "port" = 50051
        "replicas" = 3
        "update_strategy" = "RollingUpdate"
        "max_unavailable" = "33%"
        "max_surge" = "33%"
    }
    "emailservice" = @{
        "critical" = $false
        "dependencies" = @()
        "health_check" = "/health"
        "port" = 5000
        "replicas" = 2
        "update_strategy" = "RollingUpdate"
        "max_unavailable" = "50%"
        "max_surge" = "50%"
    }
    "adservice" = @{
        "critical" = $false
        "dependencies" = @()
        "health_check" = "/health"
        "port" = 9555
        "replicas" = 2
        "update_strategy" = "RollingUpdate"
        "max_unavailable" = "50%"
        "max_surge" = "50%"
    }
    "recommendationservice" = @{
        "critical" = $false
        "dependencies" = @("productcatalogservice")
        "health_check" = "/health"
        "port" = 8080
        "replicas" = 2
        "update_strategy" = "RollingUpdate"
        "max_unavailable" = "50%"
        "max_surge" = "50%"
    }
    "shippingservice" = @{
        "critical" = $false
        "dependencies" = @()
        "health_check" = "/health"
        "port" = 50051
        "replicas" = 2
        "update_strategy" = "RollingUpdate"
        "max_unavailable" = "50%"
        "max_surge" = "50%"
    }
    "redis-cart" = @{
        "critical" = $true
        "dependencies" = @()
        "health_check" = ""
        "port" = 6379
        "replicas" = 1
        "update_strategy" = "Recreate"
        "max_unavailable" = "0"
        "max_surge" = "0"
    }
}

function Test-ServiceDependencies {
    param([string]$ServiceName)
    
    Write-Info "🔍 Vérification des dépendances pour $ServiceName..."
    
    $serviceConfig = $services[$ServiceName]
    if (-not $serviceConfig) {
        Write-Warning "❌ Service $ServiceName non trouvé"
        return $false
    }
    
    $dependencies = $serviceConfig.dependencies
    if ($dependencies.Count -eq 0) {
        Write-Success "✅ Aucune dépendance - Mise à jour sûre"
        return $true
    }
    
    $allHealthy = $true
    foreach ($dep in $dependencies) {
        $depStatus = kubectl get deployment $dep -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>$null
        if ($LASTEXITCODE -eq 0 -and $depStatus -match '^(\d+)/(\d+)$') {
            $ready = [int]$matches[1]
            $desired = [int]$matches[2]
            if ($ready -eq $desired -and $ready -gt 0) {
                Write-Success "✅ Dépendance $dep : $ready/$desired pods"
            } else {
                Write-Warning "⚠️ Dépendance $dep : $ready/$desired pods (problème)"
                $allHealthy = $false
            }
        } else {
            Write-Warning "❌ Dépendance $dep : Non trouvée"
            $allHealthy = $false
        }
    }
    
    return $allHealthy
}

function Update-SingleService {
    param(
        [string]$ServiceName,
        [string]$Version = "v0.10.0",
        [string]$Strategy = "rolling"
    )
    
    Write-Info "🚀 MISE À JOUR INDÉPENDANTE : $ServiceName"
    Write-Info "=========================================="
    
    # 1. Vérifier que le service existe
    $serviceConfig = $services[$ServiceName]
    if (-not $serviceConfig) {
        Write-Warning "❌ Service $ServiceName non reconnu"
        return $false
    }
    
    # 2. Vérifier les dépendances
    if (-not (Test-ServiceDependencies -ServiceName $ServiceName)) {
        Write-Warning "❌ Dépendances non satisfaites - Abandon de la mise à jour"
        return $false
    }
    
    # 3. État avant mise à jour
    Write-Info "📊 État avant mise à jour :"
    $beforeStatus = kubectl get deployment $ServiceName -o jsonpath='{.status.readyReplicas}/{.spec.replicas}'
    $beforeImage = kubectl get deployment $ServiceName -o jsonpath='{.spec.template.spec.containers[0].image}'
    Write-Host "   Pods: $beforeStatus" -ForegroundColor Gray
    Write-Host "   Image: $beforeImage" -ForegroundColor Gray
    
    # 4. Stratégie de mise à jour
    $updateStrategy = $serviceConfig.update_strategy
    $maxUnavailable = $serviceConfig.max_unavailable
    $maxSurge = $serviceConfig.max_surge
    
    Write-Info "🔄 Stratégie: $updateStrategy (MaxUnavailable: $maxUnavailable, MaxSurge: $maxSurge)"
    
    # 5. Application de la mise à jour
    $newImage = "gcr.io/google-samples/microservices-demo/${ServiceName}:${Version}"
    
    Write-Info "⚡ Mise à jour de l'image vers: $newImage"
    kubectl set image deployment/$ServiceName server=$newImage
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "❌ Erreur lors de la mise à jour de l'image"
        return $false
    }
    
    # 6. Attendre le rollout
    Write-Info "⏳ Attente du déploiement..."
    kubectl rollout status deployment/$ServiceName --timeout=300s
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✅ Mise à jour réussie pour $ServiceName"
        
        # 7. État après mise à jour
        Write-Info "📊 État après mise à jour :"
        $afterStatus = kubectl get deployment $ServiceName -o jsonpath='{.status.readyReplicas}/{.spec.replicas}'
        $afterImage = kubectl get deployment $ServiceName -o jsonpath='{.spec.template.spec.containers[0].image}'
        Write-Host "   Pods: $afterStatus" -ForegroundColor Green
        Write-Host "   Image: $afterImage" -ForegroundColor Green
        
        return $true
    } else {
        Write-Warning "❌ Échec de la mise à jour - Rollback automatique"
        kubectl rollout undo deployment/$ServiceName
        return $false
    }
}

function Update-ServiceGroup {
    param(
        [string]$GroupType = "non-critical",
        [string]$Version = "v0.10.0"
    )
    
    Write-Info "🎯 MISE À JOUR PAR GROUPE : $GroupType"
    Write-Info "======================================"
    
    $targetServices = @()
    
    switch ($GroupType.ToLower()) {
        "critical" {
            $targetServices = $services.Keys | Where-Object { $services[$_].critical -eq $true }
        }
        "non-critical" {
            $targetServices = $services.Keys | Where-Object { $services[$_].critical -eq $false }
        }
        "frontend" {
            $targetServices = @("frontend")
        }
        "backend" {
            $targetServices = $services.Keys | Where-Object { $_ -ne "frontend" -and $_ -ne "redis-cart" }
        }
        "data" {
            $targetServices = @("redis-cart")
        }
        default {
            Write-Warning "Groupe non reconnu: $GroupType"
            return $false
        }
    }
    
    Write-Info "Services ciblés: $($targetServices -join ', ')"
    
    $successCount = 0
    foreach ($service in $targetServices) {
        Write-Host "`n" -NoNewline
        if (Update-SingleService -ServiceName $service -Version $Version) {
            $successCount++
        }
        Start-Sleep -Seconds 5  # Pause entre les services
    }
    
    Write-Success "🎉 Mise à jour terminée: $successCount/$($targetServices.Count) services mis à jour"
    return $successCount -eq $targetServices.Count
}

function Rollback-Service {
    param([string]$ServiceName)
    
    Write-Info "🔙 ROLLBACK : $ServiceName"
    Write-Info "========================="
    
    # Vérifier l'historique des rollouts
    Write-Info "📜 Historique des déploiements :"
    kubectl rollout history deployment/$ServiceName
    
    # Effectuer le rollback
    Write-Info "⏪ Rollback vers la version précédente..."
    kubectl rollout undo deployment/$ServiceName
    
    # Attendre la fin du rollback
    Write-Info "⏳ Attente du rollback..."
    kubectl rollout status deployment/$ServiceName --timeout=300s
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✅ Rollback réussi pour $ServiceName"
        
        # Afficher le nouvel état
        $status = kubectl get deployment $ServiceName -o jsonpath='{.status.readyReplicas}/{.spec.replicas}'
        $image = kubectl get deployment $ServiceName -o jsonpath='{.spec.template.spec.containers[0].image}'
        Write-Host "   Pods: $status" -ForegroundColor Green
        Write-Host "   Image: $image" -ForegroundColor Green
        
        return $true
    } else {
        Write-Warning "❌ Échec du rollback"
        return $false
    }
}

function Show-ServiceStatus {
    param([string]$ServiceName = "")
    
    if ($ServiceName) {
        Write-Info "📊 ÉTAT DU SERVICE : $ServiceName"
        Write-Info "================================"
        
        $serviceConfig = $services[$ServiceName]
        if ($serviceConfig) {
            Write-Host "Type: $(if ($serviceConfig.critical) { 'Critique' } else { 'Standard' })" -ForegroundColor $(if ($serviceConfig.critical) { 'Red' } else { 'Yellow' })
            Write-Host "Port: $($serviceConfig.port)" -ForegroundColor Gray
            Write-Host "Répliques recommandées: $($serviceConfig.replicas)" -ForegroundColor Gray
            Write-Host "Dépendances: $($serviceConfig.dependencies -join ', ')" -ForegroundColor Gray
        }
        
        # État actuel
        $status = kubectl get deployment $ServiceName -o custom-columns="READY:.status.readyReplicas,DESIRED:.spec.replicas,UP-TO-DATE:.status.updatedReplicas,AVAILABLE:.status.availableReplicas" --no-headers
        $image = kubectl get deployment $ServiceName -o jsonpath='{.spec.template.spec.containers[0].image}'
        
        Write-Host "`nÉtat actuel:" -ForegroundColor White
        Write-Host "   Status: $status" -ForegroundColor Green
        Write-Host "   Image: $image" -ForegroundColor Green
        
        # Historique des rollouts
        Write-Host "`nHistorique:" -ForegroundColor White
        kubectl rollout history deployment/$ServiceName
        
    } else {
        Write-Info "📊 ÉTAT DE TOUS LES SERVICES"
        Write-Info "============================"
        
        Write-Host "`n🔴 Services Critiques:" -ForegroundColor Red
        $criticalServices = $services.Keys | Where-Object { $services[$_].critical -eq $true }
        foreach ($service in $criticalServices) {
            $status = kubectl get deployment $service -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>$null
            $image = kubectl get deployment $service -o jsonpath='{.spec.template.spec.containers[0].image}' 2>$null
            Write-Host "   $service : $status - $($image -replace 'gcr.io/google-samples/microservices-demo/', '')" -ForegroundColor $(if ($status -match '^(\d+)/\1$') { 'Green' } else { 'Yellow' })
        }
        
        Write-Host "`n🟡 Services Standards:" -ForegroundColor Yellow
        $standardServices = $services.Keys | Where-Object { $services[$_].critical -eq $false }
        foreach ($service in $standardServices) {
            $status = kubectl get deployment $service -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>$null
            $image = kubectl get deployment $service -o jsonpath='{.spec.template.spec.containers[0].image}' 2>$null
            Write-Host "   $service : $status - $($image -replace 'gcr.io/google-samples/microservices-demo/', '')" -ForegroundColor $(if ($status -match '^(\d+)/\1$') { 'Green' } else { 'Yellow' })
        }
    }
}

function Create-ServiceUpdatePlaybooks {
    Write-Info "📝 Création des playbooks de mise à jour séparés..."
    
    # Créer un répertoire pour les playbooks de mise à jour
    if (-not (Test-Path "playbooks\updates")) {
        New-Item -Path "playbooks\updates" -ItemType Directory -Force
    }
    
    # Playbook pour mise à jour d'un service unique
    $singleUpdatePlaybook = @'
---
- name: Update Single Microservice
  hosts: localhost
  connection: local
  gather_facts: false
  
  vars:
    service_name: "{{ service_name | default('frontend') }}"
    new_version: "{{ new_version | default('v0.10.0') }}"
    namespace: "{{ namespace | default('default') }}"
    timeout: "{{ timeout | default('300s') }}"
    
  tasks:
    - name: Check if service exists
      kubernetes.core.k8s_info:
        api_version: apps/v1
        kind: Deployment
        name: "{{ service_name }}"
        namespace: "{{ namespace }}"
      register: service_check
      
    - name: Fail if service doesn't exist
      fail:
        msg: "Service {{ service_name }} not found"
      when: service_check.resources | length == 0
      
    - name: Get current service status
      kubernetes.core.k8s_info:
        api_version: apps/v1
        kind: Deployment
        name: "{{ service_name }}"
        namespace: "{{ namespace }}"
      register: current_status
      
    - name: Display current status
      debug:
        msg: "Current image: {{ current_status.resources[0].spec.template.spec.containers[0].image }}"
        
    - name: Update service image
      kubernetes.core.k8s:
        state: present
        definition:
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: "{{ service_name }}"
            namespace: "{{ namespace }}"
          spec:
            template:
              spec:
                containers:
                - name: server
                  image: "gcr.io/google-samples/microservices-demo/{{ service_name }}:{{ new_version }}"
                  
    - name: Wait for rollout to complete
      kubernetes.core.k8s_info:
        api_version: apps/v1
        kind: Deployment
        name: "{{ service_name }}"
        namespace: "{{ namespace }}"
        wait: true
        wait_condition:
          type: Progressing
          status: "True"
          reason: NewReplicaSetAvailable
        wait_timeout: "{{ timeout }}"
      register: rollout_result
      
    - name: Verify update success
      kubernetes.core.k8s_info:
        api_version: apps/v1
        kind: Deployment
        name: "{{ service_name }}"
        namespace: "{{ namespace }}"
      register: final_status
      
    - name: Display final status
      debug:
        msg: "Updated image: {{ final_status.resources[0].spec.template.spec.containers[0].image }}"
'@
    
    $singleUpdatePlaybook | Out-File -FilePath "playbooks\updates\update-single-service.yml" -Encoding UTF8
    
    # Playbook pour rollback
    $rollbackPlaybook = @'
---
- name: Rollback Single Microservice
  hosts: localhost
  connection: local
  gather_facts: false
  
  vars:
    service_name: "{{ service_name | default('frontend') }}"
    namespace: "{{ namespace | default('default') }}"
    revision: "{{ revision | default('') }}"
    
  tasks:
    - name: Get rollout history
      shell: kubectl rollout history deployment/{{ service_name }} -n {{ namespace }}
      register: rollout_history
      
    - name: Display rollout history
      debug:
        msg: "{{ rollout_history.stdout }}"
        
    - name: Rollback to previous version
      shell: |
        {% if revision %}
        kubectl rollout undo deployment/{{ service_name }} --to-revision={{ revision }} -n {{ namespace }}
        {% else %}
        kubectl rollout undo deployment/{{ service_name }} -n {{ namespace }}
        {% endif %}
      register: rollback_result
      
    - name: Wait for rollback to complete
      shell: kubectl rollout status deployment/{{ service_name }} -n {{ namespace }} --timeout=300s
      register: rollback_status
      
    - name: Display rollback result
      debug:
        msg: "Rollback completed: {{ rollback_status.stdout }}"
'@
    
    $rollbackPlaybook | Out-File -FilePath "playbooks\updates\rollback-service.yml" -Encoding UTF8
    
    Write-Success "✅ Playbooks de mise à jour créés:"
    Write-Success "   - playbooks\updates\update-single-service.yml"
    Write-Success "   - playbooks\updates\rollback-service.yml"
}

# Logique principale
switch ($Action.ToLower()) {
    "update" {
        if (-not $ServiceName) {
            Write-Warning "Nom du service requis avec -ServiceName"
            return
        }
        Update-SingleService -ServiceName $ServiceName -Version $Version -Strategy $Strategy
    }
    "update-group" {
        if (-not $ServiceName) {
            Write-Warning "Type de groupe requis avec -ServiceName (critical, non-critical, frontend, backend, data)"
            return
        }
        Update-ServiceGroup -GroupType $ServiceName -Version $Version
    }
    "rollback" {
        if (-not $ServiceName) {
            Write-Warning "Nom du service requis avec -ServiceName"
            return
        }
        Rollback-Service -ServiceName $ServiceName
    }
    "status" {
        Show-ServiceStatus -ServiceName $ServiceName
    }
    "dependencies" {
        if (-not $ServiceName) {
            Write-Warning "Nom du service requis avec -ServiceName"
            return
        }
        Test-ServiceDependencies -ServiceName $ServiceName
    }
    "create-playbooks" {
        Create-ServiceUpdatePlaybooks
    }
    "help" {
        Write-Host @"
🔄 GESTIONNAIRE DE MISES À JOUR SÉPARÉES

Usage: .\Separate-Services-Manager.ps1 -Action <action> -ServiceName <service> [-Version <version>]

Actions:
  update           Mettre à jour un service spécifique
  update-group     Mettre à jour un groupe de services
  rollback         Rollback d'un service spécifique
  status           Afficher l'état des services
  dependencies     Vérifier les dépendances d'un service
  create-playbooks Créer les playbooks Ansible de mise à jour
  help             Afficher cette aide

Options:
  -ServiceName <name>    Nom du service ou type de groupe
  -Version <version>     Version à déployer (défaut: v0.10.0)
  -Strategy <strategy>   Stratégie de déploiement (défaut: rolling)

Exemples:
  # Mise à jour d'un service
  .\Separate-Services-Manager.ps1 -Action update -ServiceName frontend -Version v0.11.0
  
  # Mise à jour par groupe
  .\Separate-Services-Manager.ps1 -Action update-group -ServiceName non-critical
  
  # Rollback
  .\Separate-Services-Manager.ps1 -Action rollback -ServiceName cartservice
  
  # État des services
  .\Separate-Services-Manager.ps1 -Action status

Services disponibles:
  Critiques: frontend, cartservice, productcatalogservice, checkoutservice, paymentservice, redis-cart
  Standards: currencyservice, emailservice, adservice, recommendationservice, shippingservice

Groupes disponibles:
  critical, non-critical, frontend, backend, data

🎯 Permet les mises à jour indépendantes et les rollbacks par service !
"@ -ForegroundColor White
    }
    default {
        Write-Warning "Action non reconnue: $Action"
        Write-Host "Utilisez -Action help pour voir les options disponibles" -ForegroundColor Gray
    }
}
