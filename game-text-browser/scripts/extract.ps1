param(
    # 游戏根目录（本地化文件的递归搜索起点）
    [string]$rootPath = ".",
    # 要提取的外语，多个用逗号分隔，如 "english,japanese"；"auto" = 自动提取除母语外发现的所有语言
    [string]$langs = "english",
    # 母语（对照基准语言），固定为中文，默认简体中文；繁体中文用 traditional_chinese
    [string]$nativeLang = "simp_chinese",
    # 配对模式：both = 仅保留外语和母语都有翻译的条目（默认，对照最干净）；union = 保留并集（缺翻译一侧留空）
    [string]$matchMode = "both",
    [string]$outputFile = "data.js"
)

Write-Host "--- 通用游戏文本提取脚本（全语言中外对照版） ---" -ForegroundColor Cyan

# Paradox 及常见游戏语言代码 -> Web Speech API 语言代码
$knownLangs = [ordered]@{
    simp_chinese        = 'zh-CN'
    traditional_chinese = 'zh-TW'
    english             = 'en'
    japanese            = 'ja'
    german              = 'de'
    french              = 'fr'
    spanish             = 'es'
    mexican             = 'es-MX'
    russian             = 'ru'
    korean              = 'ko'
    polish              = 'pl'
    italian             = 'it'
    turkish             = 'tr'
    braz_por            = 'pt-BR'
    portuguese          = 'pt'
    dutch               = 'nl'
    finnish             = 'fi'
    swedish             = 'sv'
    czech               = 'cs'
    hungarian           = 'hu'
    ukrainian           = 'uk'
}

# 1. 文本清洗（源自专业项目实践）
function Clean-Text($t) {
    if (-not $t) { return '' }
    # 处理转义换行与列表符
    $t = $t -replace '`n', "`n"
    $t = $t -replace '\\n', "`n"
    $t = $t -replace '\$EFFECT_LIST_BULLET\$', "`n• "
    $t = $t -replace '\$BULLET\$', "• "

    # 颜色与格式标记 (#T text #!)
    $t = $t -replace '#[A-Za-z]+\s*(.*?)#!', '$1'

    # 本地化引用处理 (如 [Character.GetName|E])
    $t = $t -replace '\[[^\]|]+\|[A-Za-z0-9_]+\]', ''

    # 函数引用处理 (如 [ROOT.GetCharacter.GetName])
    $t = $t -replace '\[[^\]]*\.[A-Za-z_]+\b[^\]]*\]', ''

    # 提取引用内部文本
    $t = $t -replace '\[([^\]|]+)\]', '$1'

    # 清除残留的函数关键词
    $t = $t -replace '\b(?:CHARACTER|TARGET_CHARACTER|ROOT|FROM|PREV|LIEGE|COUNCIL)\.[A-Za-z_]+\b', ''

    # 规范化空格与标点
    $t = $t -replace '[ \t]+', ' '
    $t = $t -replace ' \.', '.'
    $t = $t -replace ' ,', ','
    $t = $t -replace "`n{3,}", "`n`n"

    return $t.Trim()
}

# 2. 通用分类映射（返回 @(一级分类, 中文二级分类)，按路径关键词匹配，具体规则优先）
function Get-Category($relPath) {
    $p = $relPath.ToLower()
    # —— 军事 ——
    if ($p -match 'siege|raid|ambush') { return @('军事', '围攻袭击') }
    if ($p -match 'soldier|troop|regiment|division|legion|army|navy|fleet|unit') { return @('军事', '兵种部队') }
    if ($p -match 'weapon|firearm|artillery|ammo|armor|armour') { return @('军事', '武器装备') }
    if ($p -match 'war|battle|combat|military') { return @('军事', '战争军事') }
    # —— 剧情 ——
    if ($p -match 'quest|mission') { return @('剧情', '任务') }
    if ($p -match 'event|incident') { return @('剧情', '事件') }
    if ($p -match 'letter|message|notification|notif') { return @('剧情', '信件消息') }
    if ($p -match 'story|flavor|flavour|narrative|lore|diary') { return @('剧情', '故事文本') }
    # —— 角色 ——
    if ($p -match 'backstory|background|biography') { return @('角色', '背景故事') }
    if ($p -match 'trait') { return @('角色', '特质') }
    if ($p -match 'thought|mood|feeling|emotion') { return @('角色', '心情想法') }
    if ($p -match 'skill|perk|talent|ability') { return @('角色', '技能天赋') }
    if ($p -match 'faction') { return @('角色', '派系势力') }
    if ($p -match 'relation|opinion|friend|rival|family|marriage') { return @('角色', '人物关系') }
    if ($p -match 'interaction') { return @('角色', '社交互动') }
    if ($p -match 'hediff|disease|injur|wound|medical|symptom|sickness|illness') { return @('角色', '伤病健康') }
    if ($p -match 'bodypart|body|organ') { return @('角色', '身体部位') }
    if ($p -match 'character|pawn|colonist|creature|animal|race|species|\bnpc\b|portrait') { return @('角色', '角色人物') }
    # —— 界面 ——
    if ($p -match 'keybind|shortcut|hotkey') { return @('界面', '快捷键') }
    if ($p -match 'tooltip|tutorial|help|guide') { return @('界面', '教程帮助') }
    if ($p -match 'setting|option|config') { return @('界面', '设置选项') }
    if ($p -match 'button|menu|window|dialog|gui|interface|\bui\b|hud|\btab\b') { return @('界面', '界面控件') }
    # —— 文化 ——
    if ($p -match 'ritual|ceremony|festival') { return @('文化', '仪式节庆') }
    if ($p -match 'religion|faith|church|god|deity|temple') { return @('文化', '宗教信仰') }
    if ($p -match 'culture|tradition|custom') { return @('文化', '文化传统') }
    # —— 地理 ——
    if ($p -match 'weather|climate') { return @('地理', '天气气候') }
    if ($p -match 'biome') { return @('地理', '生态群落') }
    if ($p -match 'river|road|mountain|ocean|sea|lake|terrain|map|world|province|land|region|geograph|location|site|city') { return @('地理', '地图地理') }
    # —— 其他 ——
    if ($p -match 'item|object|goods|resource') { return @('其他', '物品资源') }
    if ($p -match 'trade|economy|money|gold|price|shop|market') { return @('其他', '经济贸易') }
    if ($p -match 'research|\btech\b') { return @('其他', '科技研究') }
    if ($p -match '\bjob\b|work|labor|building') { return @('其他', '工作建造') }
    return @('其他', '通用文本')
}

# 3. 解析单个 yml 文件，返回 key -> 清洗后文本 的哈希表
function Parse-Yml($file) {
    $map = @{}
    foreach ($line in (Get-Content $file.FullName -Encoding UTF8)) {
        # 匹配格式：  key:0 "text content"
        if ($line -match '^\s+([\w][\w.\-]*):\d+\s+"(.*)"\s*$') {
            $key = $Matches[1]
            $text = Clean-Text $Matches[2]
            if ($text.Length -lt 2) { continue }
            if ($text -match '^\$[\w_]+\$$') { continue }
            if ($text -match '^[\s\p{P}]+$') { continue }
            $map[$key] = $text
        }
    }
    return $map
}

$root = (Get-Item $rootPath).FullName

# 4. 递归扫描，自动发现游戏自带的全部语言
$allYml = Get-ChildItem -Path $root -Filter "*_l_*.yml" -Recurse -ErrorAction SilentlyContinue
$langFiles = @{}
foreach ($file in $allYml) {
    foreach ($l in $knownLangs.Keys) {
        if ($file.BaseName -like "*_l_$l") {
            if (-not $langFiles.ContainsKey($l)) {
                $langFiles[$l] = New-Object System.Collections.Generic.List[object]
            }
            $langFiles[$l].Add($file)
            break
        }
    }
}

Write-Host "发现的语言: $(if ($langFiles.Count) { ($langFiles.Keys | ForEach-Object { "$_($($langFiles[$_].Count)个文件)" }) -join ', ' } else { '无' })" -ForegroundColor DarkGray

if (-not $langFiles.ContainsKey($nativeLang)) {
    Write-Host "未找到母语($nativeLang)的本地化文件，无法制作中外对照。请确认已安装中文汉化包。" -ForegroundColor Red
    exit
}

# 确定要提取的外语列表
if ($langs -eq 'auto') {
    $wantLangs = @($langFiles.Keys | Where-Object { $_ -ne $nativeLang })
} else {
    $wantLangs = @($langs -split ',' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
}
$missing = @($wantLangs | Where-Object { -not $langFiles.ContainsKey($_) })
if ($missing.Count) {
    Write-Host "警告: 以下语言没有对应文件，将跳过: $($missing -join ', ')" -ForegroundColor Yellow
    $wantLangs = @($wantLangs | Where-Object { $langFiles.ContainsKey($_) })
}
if ($wantLangs.Count -eq 0) {
    Write-Host "没有可提取的外语文件，退出。" -ForegroundColor Red
    exit
}
Write-Host "提取目标: 母语=$nativeLang, 外语=$($wantLangs -join '/'), 配对模式=$matchMode" -ForegroundColor Cyan

# 5. 按 "文件基名||key" 聚合，先装母语（中文 z），再逐门外语装入 t
$entries = @{}

foreach ($file in $langFiles[$nativeLang]) {
    $rel = $file.FullName.Replace($root, "").TrimStart('\')
    $cc = Get-Category $rel
    $cat = $cc[0]; $cat2 = $cc[1]
    $base = $file.BaseName -replace "_l_$nativeLang$", ""
    $map = Parse-Yml $file
    foreach ($key in $map.Keys) {
        $id = "$base||$key"
        $entries[$id] = [pscustomobject]@{
            c = $cat
            c2 = $cat2
            f = $base
            k = $key
            z = $map[$key]
            t = [ordered]@{}
        }
    }
}

foreach ($lang in $wantLangs) {
    foreach ($file in $langFiles[$lang]) {
        $rel = $file.FullName.Replace($root, "").TrimStart('\')
        $cc = Get-Category $rel
        $cat = $cc[0]; $cat2 = $cc[1]
        $base = $file.BaseName -replace "_l_$lang$", ""
        $map = Parse-Yml $file
        foreach ($key in $map.Keys) {
            $id = "$base||$key"
            if ($entries.ContainsKey($id)) {
                $entries[$id].t[$lang] = $map[$key]
            } else {
                $entries[$id] = [pscustomobject]@{
                    c = $cat
                    c2 = $cat2
                    f = $base
                    k = $key
                    z = ''
                    t = [ordered]@{ $lang = $map[$key] }
                }
            }
        }
    }
}

# 6. 按配对模式过滤
if ($matchMode -eq 'both') {
    $final = @($entries.Values | Where-Object { $_.z -ne '' -and $_.t.Count -gt 0 })
} else {
    $final = @($entries.Values | Where-Object { $_.z -ne '' -or $_.t.Count -gt 0 })
}
$final = @($final | Sort-Object c, c2, f, k)
Write-Host "聚合条目: $($entries.Count)，符合配对条件: $($final.Count)" -ForegroundColor DarkGray

if ($final.Count -eq 0) {
    Write-Host "没有提取到任何有效条目，请检查文件格式（用记事本打开应能看到 key:0 ""内容"" 结构）。" -ForegroundColor Red
    exit
}

# 7. 导出：META 记录语言信息供浏览器使用，DATA 为对照数据
$codes = [ordered]@{}
foreach ($l in $wantLangs) { $codes[$l] = $knownLangs[$l] }
$meta = [ordered]@{
    native      = $nativeLang
    nativeCode  = $knownLangs[$nativeLang]
    langs       = @($wantLangs)
    codes       = $codes
    matchMode   = $matchMode
    generatedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm')
}

$jsonMeta = ConvertTo-Json $meta -Depth 5 -Compress
$jsonData = ConvertTo-Json $final -Depth 6 -Compress
# PowerShell 单元素数组序列化为对象的兜底
if ($final.Count -eq 1) { $jsonData = "[$jsonData]" }

$content = "const META = $jsonMeta;`nconst DATA = $jsonData;"
[System.IO.File]::WriteAllText((Join-Path $root $outputFile), $content, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "完成！共导出 $($final.Count) 条对照数据 -> $outputFile（UTF-8 无 BOM）" -ForegroundColor Green
