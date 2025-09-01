# Script PowerShell pour déployer les microservices Online Boutique
param(
    [string]$Action = "help",
    [string]$ServiceName = "",
    [string]$Namespace = "default",
    [string]$ImageRegistry = "gcr.io/google-samples/microservices-demo",
    [string]$Version = "latest"
)

# Configuration des couleurs pour la sortie
$Red = [System.ConsoleColor]::Red
$Green = [System.ConsoleColor]::Green
$Yellow = [System.ConsoleColor]::Yellow
$White = [System.ConsoleColor]::White

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Red
}

# Configuration des microservices
$microservices = @{
    "frontend" = @{
        "description" = "Frontend service for Online Boutique"
        "port" = 8080
        "replicas" = 1
    }
    "cartservice" = @{
        "description" = "Cart management service"
        "port" = 7070
        "replicas" = 1
    }
    "productcatalogservice" = @{
        "description" = "Product catalog service"
        "port" = 3550
        "replicas" = 1
    }
    "currencyservice" = @{
        "description" = "Currency conversion service"
        "port" = 7000
        "replicas" = 1
    }
    "paymentservice" = @{
        "description" = "Payment processing service"
        "port" = 50051
        "replicas" = 1
    }
    "shippingservice" = @{
        "description" = "Shipping cost calculation service"
        "port" = 50051
        "replicas" = 1
    }
    "emailservice" = @{
        "description" = "Email notification service"
        "port" = 8080
        "replicas" = 1
    }
    "checkoutservice" = @{
        "description" = "Order checkout service"
        "port" = 5050
        "replicas" = 1
    }
    "recommendationservice" = @{
        "description" = "Product recommendation service"
        "port" = 8080
        "replicas" = 1
    }
    "adservice" = @{
        "description" = "Advertisement service"
        "port" = 9555
        "replicas" = 1
    }
    "loadgenerator" = @{
        "description" = "Load generation service"
        "port" = 8089
        "replicas" = 1
    }
}

function Test-Prerequisites {
    Write-Info "Vérification des prérequis..."
    
    # Vérifier kubectl
    try {
        $null = kubectl version --client 2>$null
        Write-Info "kubectl: OK"
    }
    catch {
        Write-Error "kubectl n'est pas installé ou accessible"
        return $false
    }
    
    # Vérifier la connexion au cluster
    try {
        $null = kubectl cluster-info 2>$null
        Write-Info "Connexion cluster Kubernetes: OK"
    }
    catch {
        Write-Error "Impossible de se connecter au cluster Kubernetes"
        return $false
    }
    
    return $true
}

function New-KubernetesManifest {
    param(
        [string]$ServiceName,
        [hashtable]$ServiceConfig,
        [string]$Namespace,
        [string]$ImageRegistry,
        [string]$Version
    )
    
    $manifest = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $ServiceName
  namespace: $Namespace
  labels:
    app: $ServiceName
    version: $Version
spec:
  replicas: $($ServiceConfig.replicas)
  selector:
    matchLabels:
      app: $ServiceName
  template:
    metadata:
      labels:
        app: $ServiceName
        version: $Version
    spec:
      serviceAccountName: default
      terminationGracePeriodSeconds: 5
      containers:
      - name: server
        image: $ImageRegistry/${ServiceName}:$Version
        ports:
        - containerPort: $($ServiceConfig.port)
        env:
        - name: PORT
          value: "$($ServiceConfig.port)"
        - name: DISABLE_TRACING
          value: "1"
        - name: DISABLE_PROFILER
          value: "1"
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
        readinessProbe:
          periodSeconds: 5
          httpGet:
            path: /
            port: $($ServiceConfig.port)
        livenessProbe:
          periodSeconds: 5
          httpGet:
            path: /
            port: $($ServiceConfig.port)
---
apiVersion: v1
kind: Service
metadata:
  name: $ServiceName
  namespace: $Namespace
  labels:
    app: $ServiceName
spec:
  type: ClusterIP
  selector:
    app: $ServiceName
  ports:
  - name: http
    port: $($ServiceConfig.port)
    targetPort: $($ServiceConfig.port)
"@
    
    return $manifest
}

function Deploy-Service {
    param(
        [string]$ServiceName,
        [string]$Namespace,
        [string]$ImageRegistry,
        [string]$Version
    )
    
    if (-not $microservices.ContainsKey($ServiceName)) {
        Write-Error "Service '$ServiceName' non trouvé dans la configuration"
        return $false
    }
    
    $serviceConfig = $microservices[$ServiceName]
    Write-Info "Déploiement du service: $ServiceName"
    Write-Info "Description: $($serviceConfig.description)"
    
    # Créer le namespace s'il n'existe pas
    try {
        kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f - 2>$null
    }
    catch {
        # Le namespace existe probablement déjà
    }
    
    # Générer le manifest
    $manifest = New-KubernetesManifest -ServiceName $ServiceName -ServiceConfig $serviceConfig -Namespace $Namespace -ImageRegistry $ImageRegistry -Version $Version
    
    # Sauvegarder le manifest temporairement
    $tempFile = "$env:TEMP\$ServiceName-deployment.yaml"
    $manifest | Out-File -FilePath $tempFile -Encoding utf8
    
    try {
        # Appliquer le manifest
        kubectl apply -f $tempFile
        Write-Info "Service '$ServiceName' déployé avec succès"
        
        # Attendre que le déploiement soit prêt
        Write-Info "Attente que le déploiement soit prêt..."
        kubectl wait --for=condition=available --timeout=300s deployment/$ServiceName -n $Namespace
        
        return $true
    }
    catch {
        Write-Error "Erreur lors du déploiement de $ServiceName : $_"
        return $false
    }
    finally {
        # Nettoyer le fichier temporaire
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force
        }
    }
}

function Deploy-AllServices {
    param(
        [string]$Namespace,
        [string]$ImageRegistry,
        [string]$Version
    )
    
    Write-Info "Déploiement de tous les microservices..."
    
    $successCount = 0
    $totalCount = $microservices.Keys.Count
    
    foreach ($serviceName in $microservices.Keys) {
        if (Deploy-Service -ServiceName $serviceName -Namespace $Namespace -ImageRegistry $ImageRegistry -Version $Version) {
            $successCount++
        }
    }
    
    Write-Info "Déploiement terminé: $successCount/$totalCount services déployés avec succès"
    
    if ($successCount -eq $totalCount) {
        Write-Info "Tous les services ont été déployés avec succès!"
        Show-Status -Namespace $Namespace
    }
}

function Show-Status {
    param([string]$Namespace = "default")
    
    Write-Info "Statut des déploiements dans le namespace '$Namespace':"
    kubectl get deployments,services,pods -n $Namespace
}

function Remove-AllServices {
    param([string]$Namespace = "default")
    
    Write-Warning "Suppression de tous les microservices dans le namespace '$Namespace'..."
    
    foreach ($serviceName in $microservices.Keys) {
        try {
            kubectl delete deployment $serviceName -n $Namespace --ignore-not-found=true
            kubectl delete service $serviceName -n $Namespace --ignore-not-found=true
            Write-Info "Service '$serviceName' supprimé"
        }
        catch {
            Write-Warning "Erreur lors de la suppression de $serviceName : $_"
        }
    }
    
    Write-Info "Suppression terminée"
}

function Deploy-WithAnsible {
    param(
        [string]$Playbook,
        [string]$ServiceName = "",
        [string]$Namespace = "default"
    )
    
    Write-Info "Déploiement avec Ansible playbook: $Playbook"
    
    $extraVars = "namespace=$Namespace"
    if ($ServiceName) {
        $extraVars += " target_service=$ServiceName"
    }
    
    try {
        # Utiliser Python pour exécuter Ansible
        $ansibleCmd = "python -c `"import subprocess; subprocess.run(['ansible-playbook', '$Playbook', '-e', '$extraVars'], check=True)`""
        Invoke-Expression $ansibleCmd
        Write-Info "Déploiement Ansible terminé avec succès"
        return $true
    }
    catch {
        Write-Error "Erreur lors de l'exécution d'Ansible: $_"
        return $false
    }
}

function Show-Help {
    Write-Host @"
Script de déploiement des microservices Online Boutique

Usage: .\Deploy-Microservices.ps1 -Action <action> [options]

Actions:
  check         Vérifier les prérequis
  deploy-all    Déployer tous les microservices (via manifests existants)
  deploy-all-ps Déployer tous les microservices (via PowerShell)
  deploy        Déployer un microservice spécifique (-ServiceName requis)
  ansible-all   Déployer avec Ansible (tous les services)
  ansible       Déployer avec Ansible (service spécifique)
  status        Afficher le statut des déploiements
  cleanup       Supprimer tous les déploiements
  help          Afficher cette aide

Options:
  -ServiceName <name>     Nom du service à déployer (pour l'action 'deploy')
  -Namespace <namespace>  Namespace Kubernetes (défaut: 'default')
  -ImageRegistry <url>    Registre d'images (défaut: 'gcr.io/google-samples/microservices-demo')
  -Version <version>      Version des images (défaut: 'latest')

Exemples:
  .\Deploy-Microservices.ps1 -Action check
  .\Deploy-Microservices.ps1 -Action deploy-all
  .\Deploy-Microservices.ps1 -Action deploy -ServiceName frontend
  .\Deploy-Microservices.ps1 -Action status
  .\Deploy-Microservices.ps1 -Action cleanup

Services disponibles:
$($microservices.Keys -join ', ')
"@ -ForegroundColor $White
}

# Logique principale
switch ($Action.ToLower()) {
    "check" {
        if (Test-Prerequisites) {
            Write-Info "Tous les prérequis sont satisfaits!"
        }
    }
    "deploy-all" {
        # Utilise les manifests Kubernetes existants
        Write-Info "Déploiement via les manifests Kubernetes existants..."
        if (Test-Prerequisites) {
            try {
                kubectl apply -f "..\..\microservices-demo\kubernetes-manifests" -n $Namespace
                Write-Info "Tous les services ont été déployés via kubectl"
                Show-Status -Namespace $Namespace
            }
            catch {
                Write-Error "Erreur lors du déploiement: $_"
            }
        }
    }
    "deploy-all-ps" {
        if (Test-Prerequisites) {
            Deploy-AllServices -Namespace $Namespace -ImageRegistry $ImageRegistry -Version $Version
        }
    }
    "deploy" {
        if (-not $ServiceName) {
            Write-Error "Le paramètre -ServiceName est requis pour l'action 'deploy'"
            Show-Help
            exit 1
        }
        Write-Info "Déploiement du service spécifique: $ServiceName"
        if (Test-Prerequisites) {
            try {
                kubectl apply -f "..\..\microservices-demo\kubernetes-manifests\$ServiceName.yaml" -n $Namespace
                Write-Info "Service '$ServiceName' déployé via kubectl"
                kubectl wait --for=condition=available --timeout=300s deployment/$ServiceName -n $Namespace
            }
            catch {
                Write-Error "Erreur lors du déploiement de $ServiceName : $_"
            }
        }
    }
    "ansible-all" {
        if (Test-Prerequisites) {
            Deploy-WithAnsible -Playbook "playbooks\deploy-existing-manifests.yml" -Namespace $Namespace
        }
    }
    "ansible" {
        if (-not $ServiceName) {
            Write-Error "Le paramètre -ServiceName est requis pour l'action 'ansible'"
            Show-Help
            exit 1
        }
        if (Test-Prerequisites) {
            Deploy-WithAnsible -Playbook "playbooks\deploy-specific-service.yml" -ServiceName $ServiceName -Namespace $Namespace
        }
    }
    "status" {
        Show-Status -Namespace $Namespace
    }
    "cleanup" {
        Remove-AllServices -Namespace $Namespace
    }
    "help" {
        Show-Help
    }
    default {
        Write-Error "Action non reconnue: $Action"
        Show-Help
        exit 1
    }
}
