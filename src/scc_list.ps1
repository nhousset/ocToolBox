# --- Étape 1: Importer la bibliothèque de fonctions ---
. "$PSScriptRoot\functions.ps1"


# --- Étape 2: Bloc d'initialisation du script ---
try {
    # Cette partie reste ici car $PSScriptRoot est spécifique au script en cours
    $projectRoot = Split-Path -Path $PSScriptRoot -Parent
    $configFile = Join-Path $projectRoot "config\config.ini"
    
    # 1. On lit TOUTE la configuration
    $config = Get-AppConfiguration -ConfigFilePath $configFile

    # 2. On demande à la nouvelle fonction de nous préparer les variables nécessaires
    $params = Initialize-ScriptParameters -ConfigData $config

} catch {
    Write-Host "❌ ERREUR DE CONFIGURATION :" -ForegroundColor Red; Write-Host $_.Exception.Message; Read-Host "Appuyez sur Entrée..."; exit 1
}


# --- Étape 3: Vérifier la connexion ---
# On utilise la variable préparée par la fonction : $params.OcPath
Write-Host "--- Vérification de la session OpenShift existante ---" -ForegroundColor Cyan
if (-not (Test-OcConnection -OcPath $params.OcPath)) {
    Write-Host "`n❌ Vous ne semblez pas être connecté à OpenShift." -ForegroundColor Red
    Write-Host "Veuillez d'abord lancer le script 'oc_login.bat' pour vous connecter." -ForegroundColor Yellow
    Read-Host "`nAppuyez sur Entrée pour fermer."
    exit 1
}
Write-Host "✅ Session OpenShift active détectée." -ForegroundColor Green


# --- Étape 4: Opérations sur le cluster ---
# On utilise les variables préparées : $params.DefaultNamespace et $params.OcPath
if (-not [string]::IsNullOrWhiteSpace($params.DefaultNamespace)) {
    & $params.OcPath "project" $params.DefaultNamespace | Out-Null
    if (-not $?) { Write-Host "❌ Échec lors du changement vers le namespace '$($params.DefaultNamespace)'." -ForegroundColor Red; Read-Host "Appuyez sur Entrée..."; exit 1 }
    Write-Host "✅ Positionné sur le namespace '$($params.DefaultNamespace)'." -ForegroundColor Green
}

Write-Host "`n--- Liste des pods avec leur SCC ---" -ForegroundColor Cyan

# 1. On definit les arguments dans un tableau.
#    Notez que toute la chaine custom-columns est un seul element.
$getSccArgs = @(
    "get",
    "pods",
    "-n",
    $params.DefaultNamespace,
    "-o",
    "custom-columns=POD:.metadata.name,SCC:.metadata.annotations.'openshift\.io/scc'"
)

# 2. On execute avec Start-Process pour une execution fiable.
Start-Process -FilePath $params.OcPath -ArgumentList $getSccArgs -Wait -NoNewWindow