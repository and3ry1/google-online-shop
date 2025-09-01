# Script de gestion complète de l'accès web pour l'automatisation finale
param(
    [string]$Action = "help",
    [string]$Port = "8080"
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

function Start-WebAccess {
    param([string]$Port = "8080")
    
    Write-Info "🌐 Démarrage de l'accès web sur le port $Port..."
    
    # Vérifier si le port-forward existe déjà
    $existingProcess = Get-Process | Where-Object { $_.ProcessName -eq "kubectl" -and $_.CommandLine -like "*port-forward*$Port*" } 2>$null
    
    if ($existingProcess) {
        Write-Info "✅ Port-forward déjà actif sur le port $Port"
    } else {
        Write-Info "🚀 Création du port-forward sur le port $Port..."
        
        # Créer le port-forward en arrière-plan
        $job = Start-Job -ScriptBlock {
            param($Port)
            kubectl port-forward service/frontend $Port`:80 -n default
        } -ArgumentList $Port
        
        # Attendre que le port-forward soit établi
        Start-Sleep -Seconds 3
        
        # Vérifier si le port-forward fonctionne
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$Port" -TimeoutSec 5 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Success "✅ Port-forward créé et fonctionnel sur le port $Port"
                Write-Success "🌍 Application accessible sur: http://localhost:$Port"
                return $true
            }
        } catch {
            Write-Warning "⚠️ Délai d'attente pour l'établissement du port-forward"
        }
    }
    
    return $false
}

function Test-WebAccess {
    Write-Info "🧪 Test de l'accès web..."
    
    $ports = @("8080", "8081", "9090")
    $accessiblePorts = @()
    
    foreach ($testPort in $ports) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$testPort" -TimeoutSec 3 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                $accessiblePorts += $testPort
                Write-Success "✅ Port $testPort : ACCESSIBLE"
            }
        } catch {
            Write-Info "❌ Port $testPort : Non accessible"
        }
    }
    
    if ($accessiblePorts.Count -gt 0) {
        $primaryPort = $accessiblePorts[0]
        Write-Success "🌍 Application accessible sur: http://localhost:$primaryPort"
        return $primaryPort
    } else {
        Write-Warning "❌ Aucun port accessible trouvé"
        return $null
    }
}

function Open-WebBrowser {
    param([string]$Port = "8080")
    
    $url = "http://localhost:$Port"
    Write-Info "🌐 Ouverture du navigateur sur: $url"
    
    try {
        Start-Process $url
        Write-Success "✅ Navigateur ouvert avec succès"
    } catch {
        Write-Warning "⚠️ Erreur lors de l'ouverture du navigateur: $_"
        Write-Info "💡 Ouvrez manuellement: $url"
    }
}

function Stop-WebAccess {
    Write-Info "🛑 Arrêt des accès web..."
    
    # Arrêter tous les jobs kubectl port-forward
    Get-Job | Where-Object { $_.Command -like "*kubectl*port-forward*" } | Stop-Job -PassThru | Remove-Job
    
    # Tuer les processus kubectl port-forward
    Get-Process | Where-Object { $_.ProcessName -eq "kubectl" } | ForEach-Object {
        try {
            Stop-Process -Id $_.Id -Force
            Write-Info "✅ Processus kubectl arrêté: $($_.Id)"
        } catch {
            Write-Warning "⚠️ Impossible d'arrêter le processus: $($_.Id)"
        }
    }
    
    Write-Success "✅ Tous les accès web ont été arrêtés"
}

function Show-Status {
    Write-Info "📊 État de l'infrastructure et des accès..."
    
    # État des services
    Write-Info "🔧 Services Kubernetes:"
    kubectl get services -n default | Select-String "frontend"
    
    # État des pods
    Write-Info "`n🚀 Pods frontend:"
    kubectl get pods -n default | Select-String "frontend"
    
    # Processus port-forward actifs
    Write-Info "`n🌐 Accès web actifs:"
    $jobs = Get-Job | Where-Object { $_.Command -like "*kubectl*port-forward*" }
    if ($jobs) {
        $jobs | ForEach-Object { Write-Host "   Job ID: $($_.Id) - État: $($_.State)" -ForegroundColor Green }
    } else {
        Write-Host "   Aucun port-forward actif" -ForegroundColor Yellow
    }
    
    # Test des ports
    $accessiblePort = Test-WebAccess
    if ($accessiblePort) {
        Write-Success "🎉 Application accessible et prête !"
    }
}

function Complete-Setup {
    Write-Info "🎯 CONFIGURATION COMPLÈTE DE L'ACCÈS WEB"
    Write-Info "=========================================="
    
    # 1. Vérifier l'état des services
    Write-Info "1️⃣ Vérification de l'infrastructure..."
    $frontendPod = kubectl get pods -n default | Select-String "frontend.*Running"
    if (-not $frontendPod) {
        Write-Warning "❌ Aucun pod frontend en cours d'exécution"
        Write-Info "💡 Déployez d'abord avec: .\Deploy-Microservices.ps1 -Action status"
        return $false
    }
    
    # 2. Configurer l'accès web
    Write-Info "2️⃣ Configuration de l'accès web..."
    $success = Start-WebAccess -Port $Port
    
    # 3. Tester l'accès
    Write-Info "3️⃣ Test de l'accès..."
    Start-Sleep -Seconds 2
    $accessiblePort = Test-WebAccess
    
    # 4. Ouvrir le navigateur
    if ($accessiblePort) {
        Write-Info "4️⃣ Ouverture du navigateur..."
        Open-WebBrowser -Port $accessiblePort
        
        Write-Success "🎉 CONFIGURATION TERMINÉE AVEC SUCCÈS !"
        Write-Info "📋 Résumé:"
        Write-Host "   ✅ Infrastructure: Opérationnelle" -ForegroundColor Green
        Write-Host "   ✅ Accès web: http://localhost:$accessiblePort" -ForegroundColor Green
        Write-Host "   ✅ Navigateur: Ouvert automatiquement" -ForegroundColor Green
        
        return $true
    } else {
        Write-Warning "❌ Échec de la configuration de l'accès web"
        return $false
    }
}

# Logique principale
switch ($Action.ToLower()) {
    "start" {
        Start-WebAccess -Port $Port
        Test-WebAccess
    }
    "test" {
        $port = Test-WebAccess
        if ($port) {
            Open-WebBrowser -Port $port
        }
    }
    "open" {
        Open-WebBrowser -Port $Port
    }
    "stop" {
        Stop-WebAccess
    }
    "status" {
        Show-Status
    }
    "setup" {
        Complete-Setup
    }
    "help" {
        Write-Host @"
🌐 GESTIONNAIRE D'ACCÈS WEB - ONLINE BOUTIQUE

Usage: .\WebAccess-Manager.ps1 -Action <action> [-Port <port>]

Actions:
  setup     Configuration complète et ouverture automatique
  start     Démarrer l'accès web sur un port spécifique  
  test      Tester les accès et ouvrir le navigateur
  open      Ouvrir le navigateur sur un port spécifique
  stop      Arrêter tous les accès web
  status    Afficher l'état de l'infrastructure et des accès
  help      Afficher cette aide

Options:
  -Port <port>   Port à utiliser (défaut: 8080)

Exemples:
  .\WebAccess-Manager.ps1 -Action setup          # Configuration complète
  .\WebAccess-Manager.ps1 -Action start -Port 9090
  .\WebAccess-Manager.ps1 -Action test
  .\WebAccess-Manager.ps1 -Action status

🎯 Pour une configuration rapide: -Action setup
"@ -ForegroundColor White
    }
    default {
        Write-Warning "Action non reconnue: $Action"
        Write-Host "Utilisez -Action help pour voir les options disponibles" -ForegroundColor Gray
    }
}
