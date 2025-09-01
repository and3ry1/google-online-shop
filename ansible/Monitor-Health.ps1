# Script de surveillance en temps réel de la santé des microservices

param(
    [string]$Action = "monitor",
    [int]$IntervalSeconds = 30
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

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Check-ServiceHealth {
    Write-Host "`n🏥 CONTRÔLE DE SANTÉ - $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor White
    Write-Host "================================================" -ForegroundColor White
    
    # 1. État des pods
    $pods = kubectl get pods -o json | ConvertFrom-Json
    $runningPods = ($pods.items | Where-Object { $_.status.phase -eq "Running" }).Count
    $totalPods = $pods.items.Count
    
    if ($runningPods -eq $totalPods) {
        Write-Success "✅ Pods: $runningPods/$totalPods opérationnels"
    } else {
        Write-Warning "⚠️ Pods: $runningPods/$totalPods opérationnels"
    }
    
    # 2. Services critiques
    $criticalServices = @("frontend", "cartservice", "productcatalogservice", "checkoutservice", "paymentservice")
    
    foreach ($service in $criticalServices) {
        $deployment = kubectl get deployment $service -o json | ConvertFrom-Json
        $ready = $deployment.status.readyReplicas
        $desired = $deployment.spec.replicas
        
        if ($ready -eq $desired -and $ready -gt 0) {
            Write-Success "✅ $service : $ready/$desired répliques"
        } elseif ($ready -gt 0) {
            Write-Warning "⚠️ $service : $ready/$desired répliques (dégradé)"
        } else {
            Write-Error "❌ $service : $ready/$desired répliques (PANNE)"
        }
    }
    
    # 3. Test d'accès web
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 5 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Success "✅ Site web: Accessible (HTTP $($response.StatusCode))"
        }
    } catch {
        Write-Error "❌ Site web: Inaccessible"
    }
    
    # 4. Pods en erreur
    $errorPods = $pods.items | Where-Object { 
        $_.status.phase -eq "Failed" -or 
        $_.status.phase -eq "Pending" -or
        ($_.status.containerStatuses -and ($_.status.containerStatuses | Where-Object { $_.ready -eq $false }))
    }
    
    if ($errorPods) {
        Write-Warning "`n⚠️ PODS EN PROBLÈME:"
        foreach ($pod in $errorPods) {
            $name = $pod.metadata.name
            $status = $pod.status.phase
            $restarts = if ($pod.status.containerStatuses) { $pod.status.containerStatuses[0].restartCount } else { 0 }
            Write-Host "   - $name : $status (restarts: $restarts)" -ForegroundColor Yellow
        }
    }
    
    return $runningPods -eq $totalPods
}

function Auto-Heal-Services {
    Write-Info "🔧 TENTATIVE DE GUÉRISON AUTOMATIQUE"
    
    # Redémarrer les pods en erreur
    $failedPods = kubectl get pods --field-selector=status.phase=Failed -o name
    if ($failedPods) {
        Write-Info "♻️ Redémarrage des pods en échec..."
        $failedPods | ForEach-Object {
            kubectl delete $_
            Write-Info "🔄 Pod $_ supprimé pour redémarrage"
        }
    }
    
    # Vérifier les déploiements avec 0 répliques
    $deployments = kubectl get deployments -o json | ConvertFrom-Json
    foreach ($deployment in $deployments.items) {
        if ($deployment.spec.replicas -gt 0 -and $deployment.status.readyReplicas -eq 0) {
            $name = $deployment.metadata.name
            Write-Warning "🚑 Tentative de récupération de $name..."
            kubectl rollout restart deployment $name
        }
    }
}

function Start-Monitoring {
    param([int]$Interval = 30)
    
    Write-Info "👁️ DÉMARRAGE DE LA SURVEILLANCE CONTINUE"
    Write-Info "Intervalle: $Interval secondes"
    Write-Info "Appuyez sur Ctrl+C pour arrêter..."
    Write-Host ""
    
    $healthyCount = 0
    $totalChecks = 0
    
    try {
        while ($true) {
            $totalChecks++
            $isHealthy = Check-ServiceHealth
            
            if ($isHealthy) {
                $healthyCount++
            } else {
                Write-Warning "🚨 Problème détecté - Tentative de guérison..."
                Auto-Heal-Services
            }
            
            $healthPercentage = [math]::Round(($healthyCount / $totalChecks) * 100, 2)
            Write-Host "`n📊 Disponibilité: $healthPercentage% ($healthyCount/$totalChecks contrôles sains)" -ForegroundColor Cyan
            Write-Host "⏳ Prochain contrôle dans $Interval secondes...`n" -ForegroundColor Gray
            
            Start-Sleep -Seconds $Interval
        }
    } catch {
        Write-Info "🛑 Surveillance arrêtée"
        Write-Host "📊 STATISTIQUES FINALES:" -ForegroundColor White
        Write-Host "   Contrôles total: $totalChecks" -ForegroundColor Gray
        Write-Host "   Contrôles sains: $healthyCount" -ForegroundColor Green
        Write-Host "   Disponibilité: $healthPercentage%" -ForegroundColor Cyan
    }
}

function Generate-HealthReport {
    Write-Info "📋 GÉNÉRATION DU RAPPORT DE SANTÉ"
    
    $reportContent = @"
# RAPPORT DE SANTÉ - MICROSERVICES
Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## État des Services

"@
    
    $deployments = kubectl get deployments -o json | ConvertFrom-Json
    foreach ($deployment in $deployments.items) {
        $name = $deployment.metadata.name
        $ready = $deployment.status.readyReplicas
        $desired = $deployment.spec.replicas
        $status = if ($ready -eq $desired) { "✅ Sain" } elseif ($ready -gt 0) { "⚠️ Dégradé" } else { "❌ Panne" }
        
        $reportContent += "- **$name**: $ready/$desired répliques - $status`n"
    }
    
    $reportContent += @"

## Recommandations de Résilience

### Services Critiques (3+ répliques recommandées)
- frontend, cartservice, productcatalogservice
- checkoutservice, paymentservice, currencyservice

### Surveillance
- Contrôle automatique toutes les 30 secondes
- Auto-healing des pods en échec
- Alertes en cas de panne de service

### Actions en cas de Panne
1. Vérifier les logs: ``kubectl logs -f deployment/<service-name>``
2. Redémarrer le service: ``kubectl rollout restart deployment <service-name>``
3. Mettre à l'échelle: ``kubectl scale deployment <service-name> --replicas=3``
"@
    
    $reportPath = "Health-Report-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    $reportContent | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Success "✅ Rapport généré: $reportPath"
}

# Logique principale
switch ($Action.ToLower()) {
    "monitor" {
        Start-Monitoring -Interval $IntervalSeconds
    }
    "check" {
        Check-ServiceHealth
    }
    "heal" {
        Auto-Heal-Services
    }
    "report" {
        Generate-HealthReport
    }
    "help" {
        Write-Host @"
👁️ MONITEUR DE SANTÉ - MICROSERVICES

Usage: .\Monitor-Health.ps1 -Action <action> [-IntervalSeconds <seconds>]

Actions:
  monitor    Surveillance continue en temps réel (défaut)
  check      Contrôle de santé unique
  heal       Tentative de guérison automatique
  report     Génération d'un rapport de santé
  help       Afficher cette aide

Options:
  -IntervalSeconds <n>   Intervalle entre les contrôles (défaut: 30)

Exemples:
  .\Monitor-Health.ps1                           # Surveillance continue
  .\Monitor-Health.ps1 -Action check             # Contrôle unique
  .\Monitor-Health.ps1 -Action monitor -IntervalSeconds 60

🎯 Surveillance recommandée en production !
"@ -ForegroundColor White
    }
    default {
        Write-Warning "Action non reconnue: $Action"
        Write-Host "Utilisez -Action help pour voir les options disponibles" -ForegroundColor Gray
    }
}
