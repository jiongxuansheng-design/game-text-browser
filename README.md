---
name: game-text-browser
description: 游戏本地化文本提取与中外对照浏览（yml / XML-tar，多语对照、中文一/二级分类、点击朗读）
---

# Game Text Browser Creator

把游戏本地化文件提取为「中文 ↔ 外语」对照语料，生成可搜索、可按中文一/二级分类筛选、点击即朗读的静态网页。支持 Paradox 系 `.yml` 翻译目录，以及 RimWorld 这类 `tar + XML` 语言包（需按 `SKILL.md` 在项目内建专用提取脚本）。

## 功能特点

- **多语中外对照**：中文为基准，可挂英/日/韩/德/法等多门外语并一键切换；支持 both（双向有译文）/ union（并集）。
- **中文两级分类**：一级 + 中文二级（如 角色社交/特质、界面系统/对话框），侧栏折叠分类树、一级全选/半选、二级独立勾选；旧数据无 c2 自动降级。
- **模块筛选**：支持按来源模块（本体/DLC）过滤。
- **朗读练习**：点击外语/中文分别朗读，中外音色分别记忆、语速可调、离线音色优先。
- **流畅体验**：纯静态、分页渲染，万级到三万条数据秒级检索。
- **智能清洗**：自动剔除颜色代码、程序函数引用、格式符号等干扰项。

## 快速开始

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\extract.ps1 `
  -rootPath "你的游戏目录" -langs "english,japanese" `
  -nativeLang simp_chinese -matchMode both
```

将生成的 `data.js` 与 `templates/template.html` 放在同一目录，用浏览器打开 template.html 即可（建议走本地静态服务器而非 file://）。

## 目录说明

- `scripts/extract.ps1`：通用 yml 提取与清洗脚本，输出 `c/c2/f/k/z/t` 结构的 data.js。
- `templates/template.html`：Web 展示界面模板（分类树、搜索、模块筛选、多语切换、双音色朗读）。
- `SKILL.md`：技能说明，含数据契约、参数表、tar/XML 游戏（RimWorld）专用流程与 Windows PowerShell 注意事项。

## 协议

MIT License
