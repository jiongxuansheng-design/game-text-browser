---
name: game-text-browser
description: 游戏文本转单词本
---

# Game Text Browser Creator

一个高性能的游戏本地化文本提取与展示工具集。支持将 `.yml` 格式的翻译文件转化为可搜索、带语音朗读功能的 Web 页面。

## 功能特点
- **智能清洗**：自动剔除颜色代码、程序函数、极短功能词等干扰项。
- **递归搜索**：支持在游戏安装根目录一键扫描所有翻译文件。
- **流畅体验**：针对海量语料优化，支持万级数据秒级检索。
- **朗读练习**：集成 Web Speech API，点击条目即可调用系统离线语音发音。

## 快速开始
1. **下载本项目** 到本地。
2. **运行提取脚本**：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\extract.ps1 -rootPath "你的游戏目录" -lang "japanese"
   ```
3. **查看结果**：
   将生成的 `data.js` 复制到 `templates/` 文件夹下，运行 `template.html`。

## 目录说明
- `scripts/`: PowerShell 提取与清洗脚本。
- `templates/`: Web 展示界面模板。
- `SKILL.md`: Trae 技能描述文件。

## 协议
MIT License