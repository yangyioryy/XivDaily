# 回归清单

## 后端

- `/health` 返回 `ok`
- `/papers` 支持分类、关键词、时间窗口、分页、去重和缓存
- `/papers` 可区分 `ok/empty/stale/unavailable`，并在空结果时提供 `warning/empty_reason`
- `/summaries/trends` 在无模型配置时返回可解释降级结果
- `/translations` 在无模型配置时返回可解释降级结果
- `/zotero/config/status` 可区分已配置与未配置
- `/zotero/sync/{paper_id}` 具备幂等性，并返回目标集合与可见性字段
- `/zotero/exports/bibtex` 可导出 BibTeX 文本

## Android

- 首页可切换分类、时间窗口并显示趋势摘要卡片
- 首页空态可区分“筛选过窄 / 真空结果 / 请求失败”
- 收藏库可进行批量选择
- 已同步论文不会再暴露重复同步入口
- 设置页可切换主题、查看默认配置和集成状态
- 设置页可编辑并持久化用户名与头像预设

## 交付

- 运行说明和部署说明均可读
- 测试夹具与脚本包含中文注释
- 受限验收场景在 notes 中标明原因和后续手动步骤
