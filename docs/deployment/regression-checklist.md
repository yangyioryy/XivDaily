# 回归清单

## 后端

- `/health` 返回 `ok`
- `/papers` 支持分类、关键词、时间窗口、分页、去重和缓存
- `/summaries/trends` 在无模型配置时返回可解释降级结果
- `/translations` 在无模型配置时返回可解释降级结果
- `/zotero/config/status` 可区分已配置与未配置
- `/zotero/sync/{paper_id}` 具备幂等性
- `/zotero/exports/bibtex` 可导出 BibTeX 文本

## Android

- 首页可切换分类、时间窗口并显示趋势摘要卡片
- 收藏库可进行批量选择
- 设置页可切换主题、查看默认配置和集成状态

## 交付

- 运行说明和部署说明均可读
- 测试夹具与脚本包含中文注释
- 受限验收场景在 notes 中标明原因和后续手动步骤

