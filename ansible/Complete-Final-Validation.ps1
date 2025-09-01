# Script de validation finale complète du workflow Terraform + Ansible

param(
    [string]$Action = "validate-all"
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

function Test-Infrastructure {
    Write-Info "🔍 VALIDATION DE L'INFRASTRUCTURE"
    Write-Info "=================================="
    
    # Test 1: Cluster Kubernetes
    Write-Info "1️⃣ Test du cluster Kubernetes..."
    try {
        $clusterInfo = kubectl cluster-info 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✅ Cluster Kubernetes: Accessible"
        } else {
            Write-Warning "❌ Cluster Kubernetes: Non accessible"
            return $false
        }
    } catch {
        Write-Warning "❌ Erreur lors du test du cluster"
        return $false
    }
    
    # Test 2: Services déployés
    Write-Info "2️⃣ Test des services déployés..."
    $services = kubectl get services -o json | ConvertFrom-Json
    $requiredServices = @(
        "adservice", "cartservice", "checkoutservice", "currencyservice", 
        "emailservice", "frontend", "paymentservice", "productcatalogservice",
        "recommendationservice", "redis-cart", "shippingservice"
    )
    
    $deployedServices = $services.items | ForEach-Object { $_.metadata.name }
    $missingServices = @()
    
    foreach ($service in $requiredServices) {
        if ($service -notin $deployedServices) {
            $missingServices += $service
        }
    }
    
    if ($missingServices.Count -eq 0) {
        Write-Success "✅ Services: 11/11 déployés"
    } else {
        Write-Warning "❌ Services manquants: $($missingServices -join ', ')"
        return $false
    }
    
    # Test 3: Pods en cours d'exécution
    Write-Info "3️⃣ Test des pods..."
    $pods = kubectl get pods -o json | ConvertFrom-Json
    $runningPods = $pods.items | Where-Object { $_.status.phase -eq "Running" }
    $totalPods = $pods.items.Count
    $runningCount = $runningPods.Count
    
    if ($runningCount -eq $totalPods -and $totalPods -ge 11) {
        Write-Success "✅ Pods: $runningCount/$totalPods en cours d'exécution"
    } else {
        Write-Warning "❌ Pods: $runningCount/$totalPods en cours d'exécution"
        return $false
    }
    
    return $true
}

function Test-WebAccess {
    Write-Info "🌐 VALIDATION DE L'ACCÈS WEB"
    Write-Info "============================"
    
    # Test des ports disponibles
    $testPorts = @(8080, 30962, 32465)
    $accessiblePorts = @()
    
    foreach ($port in $testPorts) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$port" -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                $accessiblePorts += $port
                Write-Success "✅ Port $port : Application accessible"
            }
        } catch {
            Write-Info "❌ Port $port : Non accessible"
        }
    }
    
    if ($accessiblePorts.Count -gt 0) {
        Write-Success "🌍 Application accessible sur les ports: $($accessiblePorts -join ', ')"
        return $accessiblePorts[0]
    } else {
        Write-Warning "❌ Aucun accès web disponible"
        return $null
    }
}

function Test-AnsibleWorkflow {
    Write-Info "🔧 VALIDATION DU WORKFLOW ANSIBLE"
    Write-Info "=================================="
    
    # Test 1: Configuration Ansible
    if (Test-Path "ansible.cfg") {
        Write-Success "✅ ansible.cfg: Présent"
    } else {
        Write-Warning "❌ ansible.cfg: Manquant"
        return $false
    }
    
    if (Test-Path "inventory.yml") {
        Write-Success "✅ inventory.yml: Présent"
    } else {
        Write-Warning "❌ inventory.yml: Manquant"
        return $false
    }
    
    # Test 2: Playbooks
    $playbooks = @(
        "playbooks\deploy-microservices.yml",
        "playbooks\deploy-single-service.yml",
        "playbooks\deploy-existing-manifests.yml"
    )
      foreach ($playbook in $playbooks) {
        if (Test-Path $playbook) {
            Write-Success "✅ ${playbook}: Présent"
        } else {
            Write-Warning "❌ ${playbook}: Manquant"
            return $false
        }
    }
    
    # Test 3: Templates
    if (Test-Path "templates\microservice-deployment.yml.j2") {
        Write-Success "✅ Template Kubernetes: Présent"
    } else {
        Write-Warning "❌ Template Kubernetes: Manquant"
        return $false
    }
    
    # Test 4: Scripts PowerShell
    $scripts = @(
        "Deploy-Microservices.ps1",
        "WebAccess-Manager.ps1",
        "Validate-Final-State.ps1"
    )
      foreach ($script in $scripts) {
        if (Test-Path $script) {
            Write-Success "✅ ${script}: Présent"
        } else {
            Write-Warning "❌ ${script}: Manquant"
            return $false
        }
    }
    
    return $true
}

function Generate-FinalReport {
    param([bool]$InfrastructureOK, [bool]$WebAccessOK, [bool]$AnsibleOK, [int]$AccessPort)
    
    Write-Info "`n📋 RAPPORT FINAL DE VALIDATION"
    Write-Info "==============================="
    
    Write-Host "`n🎯 RÉSULTATS:" -ForegroundColor White
    
    if ($InfrastructureOK) {
        Write-Success "✅ Infrastructure Kubernetes: OPÉRATIONNELLE"
    } else {
        Write-Warning "❌ Infrastructure Kubernetes: PROBLÈME DÉTECTÉ"
    }
    
    if ($WebAccessOK) {
        Write-Success "✅ Accès Web: FONCTIONNEL (Port $AccessPort)"
    } else {
        Write-Warning "❌ Accès Web: NON ACCESSIBLE"
    }
    
    if ($AnsibleOK) {
        Write-Success "✅ Workflow Ansible: COMPLET"
    } else {
        Write-Warning "❌ Workflow Ansible: INCOMPLET"
    }
    
    Write-Host "`n🏆 STATUT GLOBAL:" -ForegroundColor White
    
    if ($InfrastructureOK -and $WebAccessOK -and $AnsibleOK) {
        Write-Success "🎉 AUTOMATISATION TERRAFORM + ANSIBLE : COMPLÈTEMENT RÉUSSIE !"
        Write-Success "📱 Online Boutique déployée et accessible"
        Write-Success "🔧 Workflow d'automatisation opérationnel"
        
        Write-Host "`n🌐 ACCÈS À L'APPLICATION:" -ForegroundColor White
        Write-Host "   URL: http://localhost:$AccessPort" -ForegroundColor Cyan
        Write-Host "   Commande: .\WebAccess-Manager.ps1 -Action test" -ForegroundColor Gray
        
        Write-Host "`n📚 COMMANDES UTILES:" -ForegroundColor White
        Write-Host "   Status: .\Deploy-Microservices.ps1 -Action status" -ForegroundColor Gray
        Write-Host "   Cleanup: .\Deploy-Microservices.ps1 -Action cleanup" -ForegroundColor Gray
        Write-Host "   Redeploy: .\Deploy-Microservices.ps1 -Action deploy-all" -ForegroundColor Gray
        
        return $true
    } else {
        Write-Warning "❌ AUTOMATISATION INCOMPLÈTE - Résolution requise"
        return $false
    }
}

# Logique principale
Write-Info "🚀 VALIDATION FINALE COMPLÈTE DU PROJET"
Write-Info "========================================"

$infrastructureOK = Test-Infrastructure
$accessPort = Test-WebAccess
$webAccessOK = $null -ne $accessPort
$ansibleOK = Test-AnsibleWorkflow

$finalResult = Generate-FinalReport -InfrastructureOK $infrastructureOK -WebAccessOK $webAccessOK -AnsibleOK $ansibleOK -AccessPort $accessPort

if ($finalResult) {
    Write-Success "`n🎯 PROJET COMPLÉTÉ AVEC SUCCÈS !"
    exit 0
} else {
    Write-Warning "`n⚠️ PROJET NÉCESSITE DES CORRECTIONS"
    exit 1
}
