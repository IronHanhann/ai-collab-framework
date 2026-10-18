# check.ps1 - 项目一致性检查（可移植版）
#
# 用法：把 template/ 复制成你的项目后，改下面三个变量，再跑本脚本。
#   $root = 框架根目录（含 FRAMEWORK.md 的那层）
#   $proj = 你的项目目录（含 SWITCH.md / STATE.md 的那层）
#   PS1 文件请用「UTF-8 带 BOM」保存，用 powershell.exe -File 执行。
#
# 说明：本脚本只做**单项目**能查的机械检查。框架本体的维护检查
# （root 与项目内 DISCIPLINE 版本对齐、三处同批改核验、LESSONS 标题匹配）
# 依赖本框架实例的多副本结构，不适用于新项目，故未包含。
#
# 输出约定：
#   CHECK: FAIL ...   缺必需文件，exit 1
#   CHECK: OK (...)   无问题，exit 0
#   CHECK: WARN ...   有告警（不阻塞），exit 0

$ErrorActionPreference = "Stop"

$root = "C:\path\to\ai-collab-framework"
$proj = "$root\projects\<你的项目名>"

$warns = @()
$skips = @()

# --- A. 必需依赖 ---
$required = @(
    "$root\FRAMEWORK.md",
    "$proj\SWITCH.md",
    "$proj\STATE.md"
)
$missing = @()
foreach ($d in $required) { if (-not (Test-Path $d)) { $missing += $d } }
if ($missing.Count -gt 0) {
    Write-Host "CHECK: FAIL missing deps: $($missing -join ', ')"
    exit 1
}

# 可选依赖（缺了只是跳过相关检查）
$optState  = Test-Path "$proj\STATE.md"
$optSw     = Test-Path "$proj\SWITCH.md"
$optRootSw = Test-Path "$root\SWITCH.md"
if (-not $optRootSw) { $skips += "G(root switch absent)" }

# --- A2. FRAMEWORK 版本标记 ---
$fwContent = Get-Content "$root\FRAMEWORK.md" -Encoding UTF8
$versionLines = $fwContent | Where-Object { $_ -match '^- v(\d+)\.(\d+)\.(\d+) ——' }
if ($versionLines.Count -eq 0) {
    Write-Host "CHECK: FAIL version marker not found in FRAMEWORK.md"
    exit 1
}
$maxVer = "0.0.0"
foreach ($line in $versionLines) {
    if ($line -match 'v(\d+)\.(\d+)\.(\d+)') {
        $verNum = "$($Matches[1]).$($Matches[2]).$($Matches[3])"
        if ([version]$verNum -gt [version]$maxVer) { $maxVer = $verNum }
    }
}
$latestVersion = "v$maxVer"

# --- B. STATE 顶部版本 vs FRAMEWORK 最新 ---
if ($optState) {
    $stateContent = Get-Content "$proj\STATE.md" -Encoding UTF8
    $stateTopVer = ($stateContent | Where-Object { $_ -match '当前版本：框架 (v\d+\.\d+\.\d+)' } | Select-Object -First 1)
    if ($stateTopVer -and ($stateTopVer -replace '.*框架 (v\d+\.\d+\.\d+).*', '$1') -ne $latestVersion) {
        $warns += "B1 STATE says $(($stateTopVer -replace '.*框架 (v\d+\.\d+\.\d+).*', '$1')) but FRAMEWORK latest is $latestVersion"
    }
} else { $skips += "B(STATE absent)" }

# --- G. 开关快照：STATE 的"必读索引"声明 vs 实际 SWITCH ---
if ($optState -and $optSw -and $optRootSw) {
    $rootSw = Get-Content "$root\SWITCH.md" -Raw
    $projSw = Get-Content "$proj\SWITCH.md" -Raw
    $rootOn = "?"; $projOn = "?"
    if ($rootSw -match '(?s)```yaml\s*\r?\n(.*?)```') {
        $y = $Matches[1]; if ($y -match 'enabled:\s*(\w+)') { $rootOn = $Matches[1] }
    }
    if ($projSw -match '(?s)```yaml\s*\r?\n(.*?)```') {
        $y2 = $Matches[1]; if ($y2 -match 'enabled:\s*(\w+)') { $projOn = $Matches[1] }
    }
    $readIdx = ($stateContent | Where-Object { $_ -match '必读索引' } | Select-Object -First 1)
    if ($readIdx) {
        $claimRoot = if ($readIdx -match '总开关开') { 'true' } elseif ($readIdx -match '总开关关') { 'false' } else { '?' }
        $claimProj = if ($readIdx -match '项目开关开') { 'true' } elseif ($readIdx -match '项目开关关') { 'false' } else { '?' }
        if ($claimRoot -ne '?' -and $rootOn -ne '?' -and $claimRoot -ne $rootOn) {
            $warns += "G1 STATE says root switch '$claimRoot' but SWITCH.md is '$rootOn'"
        }
        if ($claimProj -ne '?' -and $projOn -ne '?' -and $claimProj -ne $projOn) {
            $warns += "G2 STATE says project switch '$claimProj' but SWITCH.md is '$projOn'"
        }
    }
} else { $skips += "G(inputs absent)" }

# --- F. 编号撞号检查 ---
# 同一 ID 不同发送者是设计内（请求+回复共用 ID）。真正的撞号信号：
#   F1: 同一发送者 + 同一类型 在同一 ID 出现 ≥2 次
#   F3: 同一 ID 同时存在于活跃收件箱与 archive（已关闭的消息被复活）
$primaryTypes = @('task','query','result','notice','broadcast','reply','ack')
$idSenderType = @{}
$idInArchive = @{}
$idInInbox = @{}
$inboxDirs = @()
$inboxDirs += Get-ChildItem "$proj" -Directory -Filter 'inbox-*' -ErrorAction SilentlyContinue
if ($inboxDirs.Count -eq 0) { $skips += "F(no inbox dirs)" }

# 已知槽位名（来自 inbox-* 目录），按长度降序——避免 "ai" 抢先吃掉 "ai-a"
$knownSlots = @()
foreach ($d in $inboxDirs) { $knownSlots += ($d.Name -replace '^inbox-', '') }
$knownSlots = $knownSlots | Sort-Object -Property @{Expression={$_.Length}} -Descending

# 解析：{id}-{slot}-[{额外段}-]{type}.md
# 为什么不用单条正则：槽位名本身可能含连字符（如 ai-a），`([\w-]+?)-(?:[\w-]+-)*?(type)`
# 会把 sender 截成 "ai"（贪婪最小化），导致两个不同发送者被算成同一个 → F1 假阳性。
function Get-MsgParts {
    param([string]$Name)
    if ($Name -notmatch '^(\d{4})-(.+)\.md$') { return $null }
    $id = $Matches[1]; $rest = $Matches[2]
    foreach ($slot in $knownSlots) {
        if ($rest.StartsWith($slot + '-')) {
            $t = $rest.Substring($slot.Length + 1)
            if ($primaryTypes -contains $t) { return @($id, $slot, $t) }
            $last = ($t -split '-')[-1]
            if ($primaryTypes -contains $last) { return @($id, $slot, $last) }
        }
    }
    # 兜底：未知槽位名，按"最后一段是类型"处理
    $last = ($rest -split '-')[-1]
    if ($primaryTypes -contains $last) {
        $sender = $rest.Substring(0, $rest.Length - $last.Length - 1)
        return @($id, $sender, $last)
    }
    return $null
}

foreach ($dir in $inboxDirs) {
    Get-ChildItem $dir.FullName -File -Filter '*.md' -ErrorAction SilentlyContinue | ForEach-Object {
        $parts = Get-MsgParts -Name $_.Name
        if ($null -ne $parts) {
            $id = $parts[0]; $sender = $parts[1]; $type = $parts[2]
            $k = "$id|$sender|$type"
            if (-not $idSenderType.ContainsKey($k)) { $idSenderType[$k] = 0 }
            $idSenderType[$k] = $idSenderType[$k] + 1
            $idInInbox[$id] = $true
        }
    }
}
$archiveRoot = "$proj\archive"
if (Test-Path $archiveRoot) {
    Get-ChildItem $archiveRoot -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -match '^(\d{4})-') { $idInArchive[$Matches[1]] = $true }
    }
}
foreach ($k in ($idSenderType.Keys | Sort-Object)) {
    if ($idSenderType[$k] -ge 2) { $warns += "F1 duplicate primary: $k x$($idSenderType[$k])" }
}
foreach ($id in ($idInInbox.Keys | Sort-Object)) {
    if (-not $idInArchive.ContainsKey($id)) { continue }
    $archNewest = Get-ChildItem $archiveRoot -Recurse -File -Filter "$id-*.md" -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $inboxFiles = @()
    foreach ($dir in $inboxDirs) {
        Get-ChildItem $dir.FullName -File -Filter "$id-*.md" -ErrorAction SilentlyContinue | ForEach-Object { $inboxFiles += $_ }
    }
    if ($archNewest -and $inboxFiles.Count -gt 0) {
        $newestInbox = $inboxFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($newestInbox.LastWriteTime -gt $archNewest.LastWriteTime.AddDays(1)) {
            $warns += "F3 ID $id reused after close: '$($newestInbox.Name)' is newer than archive by >1 day"
        }
    }
}

# F2: 已墓碑的收件箱不应再有新文件
foreach ($dir in $inboxDirs) {
    $exited = Join-Path $dir.FullName 'EXITED.md'
    if (Test-Path $exited) {
        $exitedTime = (Get-Item $exited).LastWriteTime
        $newer = Get-ChildItem $dir.FullName -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -ne 'EXITED.md' -and $_.Name -ne '.alive' -and $_.LastWriteTime -gt $exitedTime.AddSeconds(5)
        }
        if ($newer) {
            $warns += "F2 tombstoned inbox '$($dir.Name)' got $($newer.Count) file(s) after EXITED.md"
        }
    }
}

# --- H. 每个收件箱应有 .alive ---
foreach ($dir in $inboxDirs) {
    # 含 .gitkeep 的是"占位目录"（模板里 inbox-participant / inbox-controller），跳过
    if (Test-Path (Join-Path $dir.FullName '.gitkeep')) { continue }
    if (-not (Test-Path (Join-Path $dir.FullName '.alive'))) {
        $warns += "H1 $($dir.Name) has no .alive (poll.ps1 writes it, but it must exist first)"
    }
}

# --- 输出 ---
Write-Host ""
Write-Host "=== Check ==="
Write-Host "Framework version: $latestVersion"
if ($warns.Count -eq 0) {
    Write-Host "CHECK: OK ($($versionLines.Count) versions, no drift)"
} else {
    foreach ($w in $warns) { Write-Host "CHECK: WARN $w" }
    Write-Host "CHECK: WARN $($warns.Count) issue(s) found"
}
if ($skips.Count -gt 0) {
    Write-Host "CHECK: SKIP $($skips -join ', ')"
}
exit 0
