# ======================================================================
# 可移植化提示（docs-engineer 打包前加）：
# 本脚本含硬编码路径。使用前请把下面的 $root / $main / $skill 改成你自己的
# 框架目录（用反斜杠或正斜杠均可，PowerShell 都认）。
# 当前占位：
#   $root  = "C:\path\to\ai-collab-framework"
#   $main  = "$root\projects\main"
#   $skill = "C:\path\to\ai-collab-framework-skill"
#   注意：$proj 里的 <你的项目名> 也要替换成你实际的项目目录名。
#   $me   = 你自己的收件箱槽位名（本脚本读它、写它的 .alive）
#   $peer = 对方的收件箱槽位名（一般是总控或另一个 AI）
#   $isController = 你是否为本项目总控（true 才 touch inbox-controller/.alive，见 FRAMEWORK 18.7）
# 其余逻辑保持不变。
# ======================================================================
# poll.ps1 - Standard polling script
$root = "C:\path\to\ai-collab-framework"
$proj = "$root\projects\<你的项目名>"
$me   = "ai-a"       # 改成你自己的槽位名（收件箱 = inbox-$me）
$peer = "ai-b"       # 改成对方槽位名
$isController = $false   # 本项目总控设为 $true
$now = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"

Write-Host "=== Poll ==="
Write-Host "Time: $now"
Write-Host ""

Write-Host "--- Root Switch ---"
try {
    $rootSwitch = Get-Content "$root\SWITCH.md" -Raw -ErrorAction Stop
    $rootEnabled = "?"
    if ($rootSwitch -match '(?s)```yaml\s*\r?\n(.*?)```') {
        $yaml = $Matches[1]
        if ($yaml -match 'enabled:\s*(\w+)') { $rootEnabled = $Matches[1] }
    }
    Write-Host "enabled: $rootEnabled"
} catch {
    Write-Host "ERROR: root switch"
    exit 1
}
if ($rootEnabled -eq "false") { Write-Host ">> OFF"; exit 0 }
Write-Host ""

Write-Host "--- Project Switch ---"
try {
    $projSwitch = Get-Content "$proj\SWITCH.md" -Raw -ErrorAction Stop
    $projEnabled = "?"
    $projMode = "?"
    if ($projSwitch -match '(?s)```yaml\s*\r?\n(.*?)```') {
        $yaml = $Matches[1]
        if ($yaml -match 'enabled:\s*(\w+)') { $projEnabled = $Matches[1] }
        if ($yaml -match 'mode:\s*(\w+)') { $projMode = $Matches[1] }
    }
    Write-Host "enabled: $projEnabled"
    Write-Host "mode: $projMode"
} catch {
    Write-Host "ERROR: project switch"
    exit 1
}
if ($projEnabled -eq "false" -or $projMode -eq "stopped") {
    Write-Host ">> OFF"
    Add-Content "$proj\cron-log.md" "$now | poll.ps1 | OFF"
    exit 0
}
# 只读模式：只更新 .alive + 记一行日志，不扫收件箱、不跑 check.ps1（DISCIPLINE「若 readonly → 只读，更新 .alive，结束」）
if ($projMode -eq "readonly") {
    Write-Host ">> READONLY (read-only: no inbox processing, no check)"
    try {
        Set-Content "$proj\inbox-$me\.alive" $now -ErrorAction Stop
        Write-Host "inbox-$me/.alive: OK (readonly)"
    } catch {
        Write-Host "ERROR: .alive readonly - $($_.Exception.Message)"
    }
    if ($isController) {
        try {
            Set-Content "$proj\inbox-controller\.alive" $now -ErrorAction Stop
            Write-Host "inbox-controller/.alive: OK (readonly)"
        } catch {
            Write-Host "ERROR: inbox-controller/.alive readonly - $($_.Exception.Message)"
        }
    }
    Add-Content "$proj\cron-log.md" "$now | poll.ps1 | readonly"
    Write-Host ""
    Write-Host "=== Done (readonly) ==="
    exit 0
}
Write-Host ""

Write-Host "--- .alive ---"
try {
    $ownAlivePath = "$proj\inbox-$me\.alive"
    Set-Content $ownAlivePath $now -ErrorAction Stop
    $ownAlive = (Get-Content $ownAlivePath -Raw).Trim()
    if ($ownAlive -ne $now) { Write-Host "WARN: $ownAlivePath mismatch" }
    Write-Host "inbox-$me/.alive: OK"
    if ($isController) {
        $ctPath = "$proj\inbox-controller\.alive"
        Set-Content $ctPath $now -ErrorAction Stop
        $ctAlive = (Get-Content $ctPath -Raw).Trim()
        if ($ctAlive -eq $now) { Write-Host "inbox-controller/.alive: OK" }
        else { Write-Host "WARN: inbox-controller/.alive mismatch" }
    }
} catch { Write-Host "ERROR: .alive - $($_.Exception.Message)" }
Write-Host ""

Write-Host "--- Active Projects Overview ---"
try {
    $projDirs = Get-ChildItem "$root\projects" -Directory -ErrorAction Stop
    foreach ($pd in $projDirs) {
        $swPath = "$($pd.FullName)\SWITCH.md"
        if (Test-Path $swPath) {
            $swContent = Get-Content $swPath -Raw -ErrorAction SilentlyContinue
            $pEnabled = "?"
            $pMode = "?"
            if ($swContent -match '(?s)```yaml\s*\r?\n(.*?)```') {
                $pyaml = $Matches[1]
                if ($pyaml -match 'enabled:\s*(\w+)') { $pEnabled = $Matches[1] }
                if ($pyaml -match 'mode:\s*(\w+)') { $pMode = $Matches[1] }
            }
            if ($pEnabled -eq "true" -and $pMode -ne "stopped") {
                if ($pMode -eq "readonly") {
                    # 只读项目：显示存在，但不轮询、不列收件箱（否则会被误当成待处理）
                    Write-Host "[$($pd.Name)] enabled: true, mode: readonly (not polled)"
                } else {
                    Write-Host "[$($pd.Name)] enabled: true, mode: $pMode"
                    $dbInbox = "$($pd.FullName)\inbox-$peer"
                    if (Test-Path $dbInbox) {
                        $latest = Get-ChildItem $dbInbox -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike ".alive" -and $_.Name -notlike "*.tmp" -and $_.Name -match '^\d{4}-' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                        if ($latest) {
                            Write-Host "  inbox-${peer} latest: $($latest.Name) ($($latest.LastWriteTime.ToString('HH:mm:ss')))"
                        } else {
                            Write-Host "  inbox-${peer}: (empty)"
                        }
                    }
                }
            }
        }
    }
} catch { Write-Host "WARN: active projects scan" }
Write-Host ""

Write-Host "--- Lease Check ---"
try {
    $leases = Get-Content "$proj\LEASES.md" -Raw -ErrorAction Stop
    $lines = $leases -split "`n"
    $active = @()
    $inActiveSection = $false
    foreach ($line in $lines) {
        if ($line -match '活跃租约') { $inActiveSection = $true; continue }
        if ($inActiveSection -and $line -match '已结束') { $inActiveSection = $false; continue }
        if ($inActiveSection -and $line -match '^\|') {
            if ($line -notmatch 'task_id') {
                if ($line -notmatch '---') {
                    if ($line -notmatch '（无）') {
                        $active += $line.Trim()
                    }
                }
            }
        }
    }
    if ($active.Count -gt 0) {
        Write-Host "Active leases found:"
        Write-Host "  (check LEASES.md for details)"
    } else { Write-Host "No active leases" }
} catch { Write-Host "WARN: LEASES.md" }
Write-Host ""

Write-Host "--- inbox-$me ---"
$inbox = Get-ChildItem "$proj\inbox-$me\" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike ".alive" -and $_.Name -notlike "*.tmp" } | Sort-Object LastWriteTime -Descending
if (-not $inbox) { Write-Host "(no inbox dir or empty)" }
if ($inbox) {
    $inbox | Select-Object Name, LastWriteTime -First 5 | Format-Table -AutoSize
    $allIds = @()
    foreach ($dir in @("inbox-$me", "inbox-$peer", "inbox-controller", "archive")) {
        $p = "$proj\$dir"
        if (Test-Path $p) {
            $files = Get-ChildItem $p -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{4}-' }
            if ($files) { $allIds += ($files | ForEach-Object { [int]$_.Name.Substring(0,4) }) }
        }
    }
    if ($allIds) {
        $maxId = ($allIds | Measure-Object -Maximum).Maximum
        Write-Host "Max msg id: $maxId"
    }
}
Write-Host ""

$msgCount = if ($inbox) { $inbox.Count } else { 0 }
Add-Content "$proj\cron-log.md" "$now | poll.ps1 | idle, msgs: $msgCount"
Write-Host "--- cron-log ---"
Write-Host ""

# Run check.ps1 (consistency check, WARN doesn't block poll)
Write-Host "--- check.ps1 ---"
& "$proj\check.ps1"
Write-Host ""
Write-Host "=== Done ==="