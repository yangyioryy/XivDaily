# 领域模型说明

本文件配合 `docs/openapi-draft.yaml` 使用，用中文解释核心实体的职责边界，
避免后端模型、Android DTO 和 Room 表结构各自演化。

## 1. Paper

- 作用：表示从 arXiv 聚合后返回给客户端的一篇论文。
- 生命周期：由后端查询生成，可叠加客户端本地收藏状态和 Zotero 同步状态。
- 关键字段：
  - `id`：统一主键，首版直接复用 arXiv id。
  - `summary`：原始英文摘要。
  - `translatedSummary`：按需翻译结果，可为空。
  - `favoriteState`：客户端当前是否已收藏。
  - `zoteroSyncState`：`not_synced/synced/failed` 三态同步状态。

## 2. PaperQuery

- 作用：承载客户端对论文流的筛选请求。
- 关键约束：
  - `days` 可为空；无关键词时缺省为 `7` 天，有关键词时缺省为空并触发全 arXiv 搜索。
  - `category`、`keyword` 可为空，表示不过滤。
  - 有关键词且有 `category` 时，服务层先召回关键词结果，再按分类本地过滤。
  - `page` 与 `pageSize` 共同决定分页，后端内部模型字段为 `page_size`。

## 3. TrendSummary

- 作用：承载首页顶部 AI 趋势摘要卡片。
- 关键约束：
  - 趋势摘要和首页论文列表时间窗解耦，后端固定使用最近 `3` 天。
  - 后端最多取 `8` 篇论文构造 prompt，每篇摘要截断约 `100` 字符。
  - `items` 最多 `3` 项，对应首页趋势卡片中的三条趋势。
  - `status` 为 `success` 或 `degraded`；降级原因写入 `warning`。
  - `dismissible` 控制客户端是否允许关闭。

## 4. FavoritePaper

- 作用：承载客户端本地收藏记录。
- 数据责任：
  - Room 当前冗余保存标题、作者、摘要、发布时间、主分类、链接、保存时间和 Zotero 同步状态。
  - 收藏时间、本地同步状态归 Android 本地持久化。
  - 翻译结果当前不进入收藏表，避免未设计 migration 前扩大持久化面。

## 5. IntegrationConfig

- 作用：承载设置页 Zotero 与大模型配置读写状态。
- 关键约束：
  - `api_key` 响应统一为 `{ configured, masked }`。
  - 保存请求中空白 `api_key` 表示保留既有密钥。
  - 完整密钥只能进入后端运行时配置文件或环境变量，不进入客户端 UI 状态。
  - `/ai/config/status` 与 `/zotero/config/status` 是兼容状态接口，完整配置编辑走 `/config/*`。

## 6. SyncRecord

- 作用：承载一次 Zotero 同步结果。
- 关键约束：
  - 不管成功或失败，都要有 `status` 和 `syncedAt`。
  - 失败时 `message` 必须给出可回显原因。
  - 同步响应还应返回目标集合名称、集合状态和可见性校验状态，方便客户端做可解释提示。

## 7. UserPreference

- 作用：承载设置页需要的本地默认配置。
- 当前由 Android DataStore 管理，不依赖后端接口。
- 首版覆盖：
  - 默认关注领域。
  - 默认时间窗口。
  - 主题模式。
  - 是否看过引导。
  - 昵称与头像预设。
  - 本地头像 URI。

## 8. TranslationTask

- 作用：承载单篇摘要翻译结果。
- 关键约束：
  - 首版只做同步返回，不引入后台任务队列。
  - `status` 必须区分成功、降级、失败三种结果。
  - Android 端用 `HomeUiState.translatingPaperIds` 和 `translationErrors` 表达加载与失败，不把瞬态状态写入 `PaperItem`。
