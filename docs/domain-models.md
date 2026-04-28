# 领域模型说明

本文件配合 `docs/openapi-draft.yaml` 使用，用中文解释核心实体的职责边界，
避免后端模型、Android DTO 和 Room 表结构各自演化。

## 1. Paper

- 作用：表示从 arXiv 聚合后返回给客户端的一篇论文。
- 生命周期：由后端查询生成，可叠加本地收藏状态和 Zotero 同步状态。
- 关键字段：
  - `id`：统一主键，首版直接复用 arXiv id。
  - `summary`：原始英文摘要。
  - `translatedSummary`：按需翻译结果，可为空。
  - `favoriteState`：客户端当前是否已收藏。
  - `zoteroSyncState`：三态同步状态。

## 2. PaperQuery

- 作用：承载客户端对论文流的筛选请求。
- 关键约束：
  - `days` 必填，驱动首页时间窗口逻辑。
  - `category`、`keyword` 可为空，表示不过滤。
  - `page` 与 `pageSize` 共同决定分页。

## 3. TrendSummary

- 作用：承载首页顶部 AI 趋势摘要卡片。
- 关键约束：
  - 摘要必须绑定当前 `days` 和 `category`。
  - `items` 最多 3 项，对应设计图中的三条趋势。
  - `dismissible` 控制客户端是否允许关闭。

## 4. FavoritePaper

- 作用：承载客户端本地收藏记录。
- 数据责任：
  - 主体数据以 `paperId` 关联 `Paper`。
  - 收藏时间、本地备注、同步状态归本地持久化。

## 5. SyncRecord

- 作用：承载一次 Zotero 同步结果。
- 关键约束：
  - 不管成功或失败，都要有 `status` 和 `syncedAt`。
  - 失败时 `message` 必须给出可回显原因。

## 6. UserPreference

- 作用：承载设置页需要的默认配置。
- 首版覆盖：
  - 默认关注领域
  - 默认时间窗口
  - 主题模式
  - 语言
  - 昵称与头像
  - Zotero 与大模型是否已配置

## 7. TranslationTask

- 作用：承载单篇摘要翻译结果。
- 关键约束：
  - 首版只做同步返回，不引入后台任务队列。
  - `status` 必须区分成功、降级、失败三种结果。

