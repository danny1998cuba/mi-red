param(
  [ValidatePattern('^[-a-zA-Z0-9._:]+$')]
  [string]$Serial = 'emulator-5558',
  [string]$Scenario = 'manual',
  [ValidateSet('Cold','Resume')][string]$Kind = 'Cold',
  [int]$Iterations = 5,
  [switch]$LibraryOnly,
  [switch]$PhysicalQaAuthorized
)
$ErrorActionPreference = 'Stop'
if ($Serial -notin @('emulator-5558','emulator-5560','emulator-5562') -and -not $PhysicalQaAuthorized) {
  throw 'A physical or different device requires explicit owner authorization and -PhysicalQaAuthorized.'
}
$qaAdb = Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe'
$qaPackage = 'com.mired.offline'
$qaOutput = Join-Path $PSScriptRoot '../build/phase-c'
$qaScreenshots = Join-Path $PSScriptRoot '../docs/screenshots/phase-c'
New-Item -ItemType Directory -Force -Path $qaOutput,$qaScreenshots | Out-Null

function Invoke-QaAdb([string[]]$Arguments) {
  $result = & $qaAdb -s $Serial @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) { throw "ADB failed: $($Arguments[0]) $($Arguments[1])" }
  return ($result -join "`n")
}
function Read-QaUi {
  for ($attempt=0; $attempt -lt 3; $attempt++) {
    $raw=Invoke-QaAdb @('exec-out','uiautomator','dump','/dev/tty')
    $start=$raw.IndexOf('<?xml'); $end=$raw.IndexOf('</hierarchy>')
    if ($start -ge 0 -and $end -gt $start) { return [xml]$raw.Substring($start,$end+12-$start) }
    Start-Sleep -Milliseconds 300
  }
  throw 'UI hierarchy unavailable after three attempts'
}
function Get-QaNodes([xml]$Tree) { return @($Tree.SelectNodes('//node')) }
function Tap-QaNode($Node) {
  $bounds=[regex]::Match($Node.bounds,'\[(\d+),(\d+)\]\[(\d+),(\d+)\]')
  if (-not $bounds.Success) { throw 'Control has no bounds' }
  $x=[int](([int]$bounds.Groups[1].Value+[int]$bounds.Groups[3].Value)/2)
  $y=[int](([int]$bounds.Groups[2].Value+[int]$bounds.Groups[4].Value)/2)
  Invoke-QaAdb @('shell','input','tap',"$x","$y") | Out-Null
  Start-Sleep -Milliseconds 500
}
function Tap-QaLabel([string]$Label,[switch]$Prefix) {
  $nodes=@(Get-QaNodes (Read-QaUi) | Where-Object {
    $_.package -eq $qaPackage -and
    ($(if ($Prefix) { ([string]$_.'content-desc').StartsWith($Label) } else { $_.'content-desc' -eq $Label }))
  })
  if ($nodes.Count -ne 1) { throw "Expected one app control: $Label; found $($nodes.Count)" }
  Tap-QaNode $nodes[0]
}
function Save-QaScreenshot([string]$Name) {
  Invoke-QaAdb @('shell','screencap','-p',"/sdcard/phase-c-$Name.png") | Out-Null
  Invoke-QaAdb @('pull',"/sdcard/phase-c-$Name.png",(Join-Path $qaScreenshots "$Name.png")) | Out-Null
}
function Get-QaHash {
  $sql="SELECT 'clients'; SELECT * FROM clients ORDER BY id; SELECT 'devices'; SELECT * FROM devices ORDER BY id; SELECT 'charges'; SELECT * FROM charges ORDER BY id; SELECT 'payments'; SELECT * FROM payments ORDER BY id; SELECT 'settings'; SELECT * FROM app_settings ORDER BY id;"
  $rows=Invoke-QaAdb @('shell',"run-as $qaPackage sqlite3 -readonly -cmd '.timeout 10000' -cmd '.mode quote' files/mi_red.sqlite `"$sql`"")
  return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($rows)))
}
function Wait-QaHome {
  $watch=[Diagnostics.Stopwatch]::StartNew()
  do {
    try {
      $nodes=Get-QaNodes (Read-QaUi)
      if (@($nodes | Where-Object { $_.'content-desc' -eq 'Clientes activos' }).Count -eq 1 -and
          @($nodes | Where-Object { $_.'content-desc' -eq 'Actualizar Inicio' }).Count -eq 1) { return }
    } catch { }
    Start-Sleep -Milliseconds 500
  } while ($watch.Elapsed.TotalSeconds -lt 40)
  throw 'No usable Home observed within the polling budget'
}
function Set-QaAppearance([ValidateSet('Claro','Oscuro','Automático según el sistema')][string]$Mode) {
  Tap-QaLabel 'Ajustes' -Prefix
  Tap-QaLabel 'Apariencia' -Prefix
  Tap-QaLabel $Mode
  Tap-QaLabel 'Atrás'
  Tap-QaLabel 'Inicio' -Prefix
  Wait-QaHome
}
function Test-QaNavigation {
  Tap-QaLabel 'Ajustes' -Prefix
  $nodes=Get-QaNodes (Read-QaUi)
  if (@($nodes | Where-Object { ([string]$_.'content-desc').StartsWith('Mi negocio') }).Count -ne 1) {
    throw 'Settings did not respond to the navigation tap'
  }
  Tap-QaLabel 'Inicio' -Prefix
  Wait-QaHome
}

if ($LibraryOnly) { return }
if ($Iterations -lt 1 -or $Iterations -gt 5) { throw 'Use one to five controlled launches per batch' }
$results=@()
for ($iteration=1; $iteration -le $Iterations; $iteration++) {
  $prefix="$Serial-$Scenario-$Kind-$iteration"
  if (-not $PhysicalQaAuthorized) { Invoke-QaAdb @('logcat','-c') | Out-Null }
  if ($Kind -eq 'Cold') {
    Invoke-QaAdb @('shell','am','force-stop',$qaPackage) | Out-Null
    $oldPid=Invoke-QaAdb @('shell',"pidof $qaPackage || true")
    if ($oldPid.Trim() -ne '') { throw 'Cold launch still had a process' }
  } else {
    Invoke-QaAdb @('shell','input','keyevent','KEYCODE_HOME') | Out-Null
    Start-Sleep -Milliseconds 500
  }
  $watch=[Diagnostics.Stopwatch]::StartNew()
  $launch=Invoke-QaAdb @('shell','am','start','-W','-a','android.intent.action.MAIN','-c','android.intent.category.LAUNCHER','-n',"$qaPackage/.MainActivity")
  $launch | Set-Content -LiteralPath (Join-Path $qaOutput "$prefix-launch.txt")
  $usable=$false; $interactive=$false; $failure=$null; $observedMs=$null
  try {
    Wait-QaHome
    $observedMs=$watch.ElapsedMilliseconds
    $usable=$true
    Test-QaNavigation
    $interactive=$true
  } catch { $failure=$_.Exception.Message }
  if (-not $PhysicalQaAuthorized -and ($iteration -eq 1 -or $iteration -eq $Iterations -or -not $interactive)) {
    Save-QaScreenshot $prefix
  }
  $logs = if ($PhysicalQaAuthorized) {
    $appPid=(Invoke-QaAdb @('shell','pidof',$qaPackage)).Trim()
    if ($appPid -match '^\d+$') { Invoke-QaAdb @('logcat','-d','-v','threadtime',"--pid=$appPid") } else { '' }
  } else { Invoke-QaAdb @('logcat','-d','-v','threadtime') }
  $logs | Set-Content -LiteralPath (Join-Path $qaOutput "$prefix-logcat.txt")
  if (-not $interactive -or $logs -match 'ANR in |FATAL EXCEPTION') {
    if (-not $PhysicalQaAuthorized) {
      Invoke-QaAdb @('shell','dumpsys','activity','activities') | Set-Content -LiteralPath (Join-Path $qaOutput "$prefix-activity.txt")
    }
    Invoke-QaAdb @('shell','dumpsys','gfxinfo',$qaPackage) | Set-Content -LiteralPath (Join-Path $qaOutput "$prefix-gfxinfo.txt")
  }
  $result=[pscustomobject]@{
    timestamp=(Get-Date).ToString('o'); serial=$Serial; scenario=$Scenario; kind=$Kind; iteration=$iteration
    launchStatus=[regex]::Match($launch,'Status: (\w+)').Groups[1].Value
    launchState=[regex]::Match($launch,'LaunchState: (\w+)').Groups[1].Value
    totalTimeMs=[regex]::Match($launch,'TotalTime: (\d+)').Groups[1].Value
    usableObservedMs=$observedMs; interactive=$interactive; usable=$usable; failure=$failure
    renderer=$(if ($logs -match 'Using the Impeller rendering backend') { 'Impeller' } elseif ($Kind -eq 'Resume') { 'existing process' } else { 'see log' })
    appAnr=$(if ($PhysicalQaAuthorized) { $null } else { $logs -match 'ANR in com\.mired\.offline' })
    systemUiAnr=$(if ($PhysicalQaAuthorized) { $null } else { $logs -match 'ANR in com\.android\.systemui' })
    logCoverage=$(if ($PhysicalQaAuthorized) { 'app process only; OS ANR events not collected' } else { 'full synthetic AVD logcat' })
    fatal=($logs -match 'FATAL EXCEPTION|Fatal signal|Abort message')
  }
  $results+=$result
  $results | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $qaOutput "$Serial-$Scenario-$Kind.json")
  $result | ConvertTo-Json -Compress
}
Invoke-QaAdb @('shell','dumpsys','gfxinfo',$qaPackage) | Set-Content -LiteralPath (Join-Path $qaOutput "$Serial-$Scenario-$Kind-gfxinfo.txt")
