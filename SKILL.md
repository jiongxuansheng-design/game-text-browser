---
name: game-text-browser
description: 游戏本地化文本提取与中外对照浏览（yml / XML-tar，多语对照、中文一/二级分类、点击朗读）
---

# 游戏文本浏览器制作指南（Stellaris/CK3 · RimWorld · 通用）

本指南记录从游戏原始本地化文件（`.yml` / tar 内 XML）到制作高性能、可检索、可朗读的 Web 浏览器的全过程。支持单语单词本与「中文 ↔ 多门外语」对照两种模式。

核心流程：`游戏本地化文件` -> `PowerShell 提取脚本` -> `数据文件 (data.js)` -> `Web 界面 (template.html)`

---

## 前置检查：文件格式与加密说明

在开始制作之前，必须确认游戏文本的可读性：

1. **常见格式**：
   - Paradox 游戏（Stellaris/CK3/HOI4）通常使用 `.yml`。
   - RimWorld / Unity 系常见 tar 包内 XML（`<LanguageData>`）。
   - 其他游戏可能使用 `.csv`, `.json`, `.txt`, `.xml` 或 `.lua`。
   - 只要是**未加密的纯文本格式**，都可以通过修改正则表达式进行提取。

2. **加密与封包限制**：
   - **加密文件**：如果用记事本打开显示为乱码或二进制数据，说明文件已加密。**本指南的方法无法处理加密文件**，需要先寻找解密工具。
   - **封包文件**：如果文本被封入 `.pak`, `.bin`, `.dat` 等大包中，需要先使用专门的解包工具（如 QuickBMS）将文件提取出来。RimWorld 的 `.tar` 可直接用系统 `tar.exe` 解包（见后文专章）。
   - **验证方法**：手动用记事本打开一个翻译文件。yml 能看到 `key:0 "内容"`、XML 能看到 `<Key>内容</Key>` 结构，则可继续。

---

## 自动化文件检索（支持根目录运行）

在游戏根目录运行提取脚本时，使用 PowerShell 递归搜索自动寻找翻译文件：

```powershell
# 自动寻找所有日语本地化文件（P 社 yml 命名：xxx_l_japanese.yml）
$targetLang = "japanese"
$ymlFiles = Get-ChildItem -Path "." -Filter "*_l_$($targetLang).yml" -Recurse

foreach ($file in $ymlFiles) {
    Write-Host "发现文件: $($file.FullName)"
    # 执行提取逻辑...
}
```

---

## 第一步：数据提取与清洗（PowerShell）

游戏原始文件包含大量代码（如颜色代码 `#Y`, `#b`，函数引用 `[ROOT.GetCharacter.GetName]` 等），脚本负责提取干净文本。

### 1. YML 核心提取正则

```powershell
# 匹配格式：  key:0 "text content"
if ($line -match '^\s+([\w][\w.\-]*):\d+\s+"(.*)"\s*$') {
    $key = $Matches[1]
    $raw = $Matches[2]
}
```

### 2. 文本清洗规则

- **颜色标记**：`#T text #!` -> `text`
- **本地化引用**：`[Character.GetFirstName]` 之类 -> 直接删除或简化
- **列表符/换行**：`$BULLET$` -> `• `，`` `n `` 与 `\n` -> 真正换行
- 数据文件统一输出 **UTF-8（无 BOM）**，否则浏览器解析中文乱码。

### 3. 分类逻辑：中文两级分类 c / c2（新版增强）

每条数据带：
- `c`：一级分类（中文，如 角色社交、军事、界面系统、剧情、文化、地理）。
- `c2`：二级分类（中文，如 角色社交/特质、角色社交/心情想法、剧情/任务、界面系统/对话框）。

通用脚本 `Get-Category($relPath)` 按相对路径关键词返回 `@(一级, 二级)`，具体规则优先，例如：

```powershell
if ($p -match 'trait') { return @('角色', '特质') }
if ($p -match 'thought|mood|feeling|emotion') { return @('角色', '心情想法') }
if ($p -match 'quest|mission') { return @('剧情', '任务') }
if ($p -match 'weapon|firearm|artillery|ammo') { return @('军事', '武器装备') }
if ($p -match 'ritual|ceremony|festival') { return @('文化', '仪式节庆') }
```

为新游戏适配时：优先扩充 `Get-Category` 关键词表；Def/文件类型特别规整的游戏（如 RimWorld），用专用映射表覆盖全部类型，跑完用 Node 校验 c2 缺失数为 0。

### 4. 通用提取脚本参数（scripts/extract.ps1）

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\extract.ps1 `
  -rootPath "游戏目录" -langs "english,japanese" `
  -nativeLang simp_chinese -matchMode both -outputFile data.js
```

| 参数 | 默认 | 说明 |
|---|---|---|
| `-rootPath` | `.` | 本地化文件递归搜索起点 |
| `-langs` | `english` | 外语代码逗号分隔；`auto` = 自动收全部非母语语言 |
| `-nativeLang` | `simp_chinese` | 母语基准（对照基准固定为中文）；繁体用 `traditional_chinese` |
| `-matchMode` | `both` | `both` 仅保留母语与外语都有译文的条目（对照最干净）；`union` 保留并集，缺侧留空 |
| `-outputFile` | `data.js` | 输出文件名（UTF-8 无 BOM） |

---

## 第二步：大数据量优化（关键）

数据超过 10MB 时**绝对不要嵌入 HTML**，否则双击打不开或浏览器崩溃。

### 数据与界面分离

```html
<script src="data.js"></script>
<script>
  // 顶层 const 不挂 window，直接引用标识符即可
  console.log(DATA.length);
</script>
```

> **坑（已修）**：data.js 顶层是 `const META` / `const DATA`，页面内联脚本若再 `const META` 会报
> `Identifier 'META' has already been declared` 导致整页空白。模板内联脚本统一用 IIFE 包裹：
> `(function(META){ ... })(typeof META !== 'undefined' ? META : null);`
> 取数据用 `typeof DATA !== 'undefined' ? DATA : []`，不要用 `window.DATA`（ES6 const 不挂 window）。

### 搜索性能

搜索框用 `setTimeout` 防抖（约 200ms），避免每敲一个字就全量过滤几万条。

---

## 第三步：前端开发要点（templates/template.html）

### 1. 分页渲染（50 条/页）

```javascript
function render() {
  const start = (currentPage - 1) * pageSize;
  const slice = filtered.slice(start, start + pageSize);
  // 只渲染这一页
}
```

### 2. 容错处理

处理文件名/文本拆分时先检查类型，防止崩溃：

```javascript
function translateFname(f) {
  if (!f || typeof f !== 'string') return f || ''; // 防止 f.split 报错
  const words = f.split('_');
}
```

### 3. 两级分类树（新版增强）

- 侧栏按 `c` 分组：一级复选框（粗体）+ ▶/▼ 折叠箭头（默认全展开）+ 二级复选框列表（中文名 + 计数）。
- **默认全部不勾选，初始显示 0 条；勾哪个分类才显示哪个分类的条目**（空白结果区给出引导提示），避免大数据集（数万条）首屏全量渲染。
- 选中状态：`selectedCats`（空 = 一个都不显示）+ `selectedSub: Map<一级, Set<二级>>`（空 Set = 该一级全选，非空 = 只看勾中的二级）。
- 一级框三态：全选勾选、部分选中显示横杠（`indeterminate`）、全不选空白；二级全部重新勾满时自动归一为全选。
- **二级勾选框的视觉态必须由一级状态推导**：`subChecked = 一级已选 && (set 为空→全勾 | set 非空→set.has(二级))`；一级未选时二级一律不渲染 `checked`，否则会出现"看着是勾上的、点一下反而没反应"的假选中。一级未选时直接点二级 = 只勾这一个二级（自动选中一级并进入部分选中态）。
- **旧数据兼容**：数据没有 `c2` 字段时（老 Stellaris/CK3 数据，`t` 为字符串、无 `z`），自动降级为一级扁平列表和单语模式，老页面不需要改数据。

### 4. 模块筛选与多语切换

- 数据带来源模块（本体/DLC）时提供模块下拉，过滤与分类/搜索叠加。
- 外语下拉来自 `META.langs`，切换即改对照语言；显示模式：中外对照 / 仅外语 / 仅中文。

---

## 第四步：部署与运行

```text
/项目文件夹/
├── template.html (或 群星文本浏览器.html)
└── data.js       (海量数据，可能几十 MB，不放进技能目录)
```

- 数据用 `<script src="...">` 引入而非 `fetch()`，file:// 下才不会被跨域拦截；推荐起本地静态服务器（`npx http-server` 或 node 简易 http）打开，改完提醒用户 Ctrl+F5 强刷。
- **data.js 是具体游戏的数据产物，不属于全局技能**；技能只放脚本和模板。

---

## 第五步：本地离线语音朗读（Web Speech API）

### 1. 枚举语音并离线优先

浏览器枚举系统全部语音，`localService: true` 表示本地离线；语音列表异步加载，必须监听 `onvoiceschanged`。

```javascript
function loadVoices() {
    const voices = speechSynthesis.getVoices();
    const ja = voices.find(v => v.lang.startsWith('ja') && v.localService)
            || voices.find(v => v.lang.startsWith('ja'));
}
if (speechSynthesis.onvoiceschanged !== undefined) {
    speechSynthesis.onvoiceschanged = loadVoices;
}
```

### 2. 多语双音色（新版增强）

- **外语音色按语言分别记忆**：`settings.fVoice[lang]`，切换外语时下拉自动切到该语言上次选的音色；下拉里把匹配语言的离线音色排在前面，其余音色放「其他音色」分组。
- **中文音色独立选择**（`settings.zVoice`），点击外语段用外语音色、点击中文段用中文音色。
- 语言代码优先取 `META.codes[lang]`（如 `japanese -> ja`、`braz_por -> pt-BR`），无 META 时用内置兜底表。

### 3. 语速滑块与配置持久化

```html
语速: <span id="rateVal">1.0</span>x
<input type="range" id="voiceRate" min="0.5" max="2.0" step="0.1" value="1.0">
```

`settings = { lang, mode, rate, module, fVoice:{}, zVoice:'' }` 整体 JSON 存 `localStorage`，刷新后语言、模式、语速、模块、中外音色全部还原。可点击文本需有 `cursor:pointer` 和 hover 变色。

---

## 第六步：tar/XML 类游戏专用流程（RimWorld）

RimWorld 语言包是 `Data/<模块>/Languages/*.tar`（Core/Royalty/Ideology/Biotech/Anomaly/Odyssey），tar 内 XML 为 `<LanguageData>`，条目带 `<!-- EN: 原文 -->` 注释。通用 yml 脚本不适用，在游戏项目输出目录建专用脚本（RimWorld 蓝本：项目 `TextBrowser/extract-rimworld.ps1`，可复制改写），输出仍遵守下文数据契约。

已解决的坑：

1. **tar 非 ASCII 文件名**：GBK 控制台对捷克/韩等文件名报 “Failed to open archive” 且静默失败。先 `Copy-Item -LiteralPath` 到 `$env:TEMP` 下 ASCII 临时名（如 `rw_{模块}_{code}.tar`）再 `tar -xf`；tar 前后临时把 `$ErrorActionPreference` 切为 `Continue`。
2. **含中文的 .ps1 必须存 UTF-8 BOM**，否则 Windows PowerShell 5.1 按 GBK 读会乱码；编辑后 BOM 丢失要显式补回。
3. **PS 5.1 兼容**：不用 `??`；命令行链式用 `;` 不用 `&&`。
4. **大 JSON 不用 PowerShell 序列化**（27 语言约 5–6 分钟）；结构修补用 Node 原地改 data.js。PS `ConvertFrom-Json` 对超大单行 JSON 会报错，数据校验用 Node。
5. XML 解析：母语译文取节点文本，英语取 `<!-- EN: -->` 注释，其余语言各解一包；Def 条目按 Def 类型映射 `$defCatTable`（约 140 种类型→「一级|二级」），Keyed 条目按文件名映射 `$keyedCat2`（Alerts→警报、Letters→信件、Dialogs_Various→对话框等）。

---

## 数据契约（data.js）

```js
const META = {
  native: 'simp_chinese', nativeCode: 'zh-CN',
  langs: ['english', 'japanese'],                 // 实际包含的外语
  codes: { english: 'en', japanese: 'ja' },       // -> Web Speech 语言码
  matchMode: 'both', generatedAt: '2026-10-02 13:00'
};
const DATA = [
  { c: '角色社交', c2: '特质', f: 'Core/DefInjected/.../文件', k: '条目Key',
    z: '中文译文', t: { english: 'English text', japanese: '日本語' } },
  // 旧格式（单语单词本）：{ c:'军事', f:'文件', k:'Key', t:'外语字符串' } —— 模板自动兼容
];
```

字段：`c` 一级分类、`c2` 二级分类（可省略）、`f` 来源文件、`k` 条目键（均可搜索）、`z` 中文、`t[语言代码]` 外语。

---

## 交付检查清单

1. 前置检查文件未加密；yml 用 `scripts/extract.ps1`（设好 -rootPath/-langs/-matchMode），tar/XML 游戏在项目内建专用脚本。
2. 分类映射覆盖全部条目：Node 校验 c2 缺失数 = 0、各二级计数之和 = 一级计数。
3. template.html 与 data.js 放同目录；Node `new Function()` 校验内联脚本语法。
4. 起静态服务器实测：搜索防抖、模块筛选、一级展开/折叠、全选/半选/单选二级、多语切换、中外双音色朗读、设置刷新后还原，均无控制台报错。

## 快速制作下一个浏览器

1. yml 游戏：复制 `scripts/extract.ps1`，改路径与 `-langs` 运行生成 data.js，必要时扩充 `Get-Category` 关键词。
2. tar/XML 游戏：复制项目内 `extract-rimworld.ps1` 蓝本，改 tar 名映射与分类映射表。
3. 复制 `templates/template.html` 到 data.js 同目录（老数据无需改造，自动降级）。
4. 刷新页面，搞定。

## 目录

- `scripts/extract.ps1`：通用 yml 提取与清洗（多语对照、c/c2 两级中文分类）。
- `templates/template.html`：浏览页模板（分类树、搜索、模块筛选、多语切换、中外双音色朗读、设置记忆）。
- `SKILL.md` / `README.md`：本说明。

## 协议

MIT License
