<#
.SYNOPSIS
  Script de nettoyage AAD / MDM / Intune pour corriger les erreurs d’inscription
  (ex : MMP-C 0x8018000b, "Le jeu de clés n'existe pas", problèmes d'inscription MDM).

.NOTES
  - À lancer en PowerShell en tant qu’administrateur.
  - Un redémarrage est recommandé après exécution.
#>

[CmdletBinding()]
param(
    [switch]$SkipDsregLeave,      # N'exécute pas dsregcmd /leave si précisé
    [switch]$SkipRegCleanup,      # N'efface pas les clés de registre MDM si précisé
    [switch]$SkipCertCleanup      # N'efface pas les certificats MDM/Intune si précisé
)

Write-Host "=== Script de nettoyage AAD / MDM / Intune ===" -ForegroundColor Cyan

# ---------------------------------------------------------
# 1. Vérification des droits administrateur
# ---------------------------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERREUR] Ce script doit être lancé en tant qu'administrateur." -ForegroundColor Red
    Write-Host "Fais un clic droit sur PowerShell et choisis 'Exécuter en tant qu'administrateur'."
    exit 1
}

# ---------------------------------------------------------
# 2. Afficher l'état actuel AAD / MDM
# ---------------------------------------------------------
Write-Host "`n--- État actuel de l'appareil (dsregcmd /status) ---`n" -ForegroundColor Yellow
try {
    dsregcmd /status
} catch {
    Write-Host "[AVERTISSEMENT] Impossible d'exécuter dsregcmd /status. L'outil n'est peut-être pas disponible." -ForegroundColor Yellow
}

# ---------------------------------------------------------
# 3. Sortir de Azure AD / Entra ID (dsregcmd /leave)
# ---------------------------------------------------------
if (-not $SkipDsregLeave) {
    Write-Host "`n--- Étape 1 : dsregcmd /leave ---" -ForegroundColor Cyan
    $confirmLeave = Read-Host "Souhaites-tu exécuter 'dsregcmd /leave' pour sortir de Azure AD / MDM ? (O/N)"
    if ($confirmLeave -match '^[oOyY]') {
        try {
            Write-Host "Exécution de 'dsregcmd /leave'..." -ForegroundColor Green
            dsregcmd /leave
            Write-Host "Commande dsregcmd /leave exécutée. Un redémarrage sera probablement nécessaire." -ForegroundColor Green
        } catch {
            Write-Host "[ERREUR] Échec de 'dsregcmd /leave' : $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "Étape 'dsregcmd /leave' ignorée à ta demande." -ForegroundColor Yellow
    }
} else {
    Write-Host "SkipDsregLeave = True → étape dsregcmd /leave ignorée." -ForegroundColor Yellow
}

# ---------------------------------------------------------
# 4. Nettoyage des clés de registre d’inscription MDM / Intune
# ---------------------------------------------------------
if (-not $SkipRegCleanup) {
    Write-Host "`n--- Étape 2 : Nettoyage des clés de registre MDM / Intune ---" -ForegroundColor Cyan

    $regPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Enrollments',
        'HKLM:\SOFTWARE\Microsoft\Enrollments\Status',
        'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts',
        'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger'
    )

    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            Write-Host "Traitement du chemin : $path" -ForegroundColor Yellow
            try {
                # On ne supprime pas la clé racine, seulement les sous-clés GUID
                Get-ChildItem -Path $path -ErrorAction Stop | ForEach-Object {
                    Write-Host "  → Suppression de $($_.Name)" -ForegroundColor Green
                    Remove-Item -Path $_.PsPath -Recurse -Force -ErrorAction Stop
                }
            } catch {
                Write-Host "[ERREUR] Impossible de nettoyer $path : $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "Chemin non trouvé (ignoré) : $path" -ForegroundColor DarkGray
        }
    }
} else {
    Write-Host "SkipRegCleanup = True → nettoyage registre MDM ignoré." -ForegroundColor Yellow
}

# ---------------------------------------------------------
# 5. Suppression des certificats MDM / Intune / MS-Organization-Access
# ---------------------------------------------------------
if (-not $SkipCertCleanup) {
    Write-Host "`n--- Étape 3 : Nettoyage des certificats liés à MDM / Intune ---" -ForegroundColor Cyan

    $stores = @(
        "Cert:\LocalMachine\My",      # Certificats personnels machine
        "Cert:\LocalMachine\Root",    # Autorités racines
        "Cert:\LocalMachine\CA"       # Autorités intermédiaires
    )

    foreach ($store in $stores) {
        if (Test-Path $store) {
            Write-Host "Analyse du magasin de certificats : $store" -ForegroundColor Yellow
            try {
                $certs = Get-ChildItem $store | Where-Object {
                    $_.Subject -like "*MS-Organization-Access*" -or
                    $_.Subject -like "*Intune*" -or
                    $_.Subject -like "*Microsoft Intune*" -or
                    $_.FriendlyName -like "*Intune*" -or
                    $_.Issuer -like "*MS-Organization-Access*"
                }

                if ($certs.Count -gt 0) {
                    foreach ($cert in $certs) {
                        Write-Host "  → Suppression certificat : $($cert.Subject)" -ForegroundColor Green
                        try {
                            Remove-Item -Path $cert.PSPath -Force -ErrorAction Stop
                        } catch {
                            Write-Host "[ERREUR] Impossible de supprimer le certificat $($cert.Subject) : $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                } else {
                    Write-Host "  Aucun certificat lié à Intune / MS-Organization-Access trouvé dans $store." -ForegroundColor DarkGray
                }
            } catch {
                Write-Host "[ERREUR] Problème lors de la lecture du magasin $store : $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "Magasin introuvable (ignoré) : $store" -ForegroundColor DarkGray
        }
    }
} else {
    Write-Host "SkipCertCleanup = True → nettoyage des certificats ignoré." -ForegroundColor Yellow
}

# ---------------------------------------------------------
# 6. Rappel TPM (manuel)
# ---------------------------------------------------------
Write-Host "`n--- NOTE TPM ---" -ForegroundColor Cyan
Write-Host "Si les erreurs persistent et que tu as des erreurs TPM liées aux clés, tu peux envisager un 'Clear TPM'" -ForegroundColor Yellow
Write-Host "Commande : tpm.msc → Actions → Effacer le TPM (⚠ vérifie BitLocker avant !)" -ForegroundColor Red

# ---------------------------------------------------------
# 7. Fin et recommandations
# ---------------------------------------------------------
Write-Host "`n=== Nettoyage terminé ===" -ForegroundColor Cyan
Write-Host "1) Redémarre la machine." -ForegroundColor White
Write-Host "2) Rejoins à nouveau Azure AD / Entra ID (ou domaine hybride si besoin)." -ForegroundColor White
Write-Host "3) Laisse l'inscription automatique Intune / MDM se refaire." -ForegroundColor White

Write-Host "`nTu peux relancer 'dsregcmd /status' après redémarrage pour vérifier l'état." -ForegroundColor Green
