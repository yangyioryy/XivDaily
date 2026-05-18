import {
  FavoritePaperItem,
  PaperChatMessage,
  PaperChatUsedPaper,
  PaperItem,
  SettingsStatus,
  TrendSummary
} from '../model/AppModels';
import { IntegrationConfigPayload, PaperQuery } from '../model/ApiModels';

export class PaperService {
  private readonly seedPapers: PaperItem[] = [
    {
      id: '2405.00001',
      title: '3D 场景神经表示与布局生成',
      authors: ['A. Researcher', 'B. Author'],
      summary: '研究通过 Transformer 和双系统方法提升从多视图图像重建 3D 几何及生成仿真训练场景的能力。',
      translatedSummary: '研究通过 Transformer 和双系统方法提升从多视图图像重建 3D 几何及生成仿真训练场景的能力。',
      publishedAt: '2026-05-18',
      updatedAt: '2026-05-18',
      primaryCategory: 'cs.CV',
      sourceUrl: 'https://arxiv.org/abs/2405.00001',
      pdfUrl: 'https://arxiv.org/pdf/2405.00001',
      zoteroSyncState: 'not_synced',
      favoriteState: true
    },
    {
      id: '2405.00002',
      title: '多模态模型融合与优化',
      authors: ['C. Scientist', 'D. Engineer'],
      summary: '聚焦视觉-语言-动作网络蒸馏、农业识别分割及模态竞争力监控，提升多模态校准性能。',
      publishedAt: '2026-05-18',
      updatedAt: '2026-05-18',
      primaryCategory: 'cs.CV',
      sourceUrl: 'https://arxiv.org/abs/2405.00002',
      pdfUrl: 'https://arxiv.org/pdf/2405.00002',
      zoteroSyncState: 'synced',
      favoriteState: true
    }
  ];

  private readonly seedTrendSummary: TrendSummary = {
    intro: '最近 3 天 cs.CV 领域聚焦 3D 场景表示、多模态模型优化与生成式模型改进。',
    status: 'ok',
    items: [
      {
        rank: 1,
        trendTitle: '3D 场景神经表示与布局生成',
        summary: '研究流过渡到 Transformer 几何表征、3D 布局表达与仿真建模。',
        representativePaperIds: ['2405.00001']
      },
      {
        rank: 2,
        trendTitle: '多模态模型融合与优化',
        summary: '视觉-语言-动作和生成式蒸馏正在成为近期高频方向。',
        representativePaperIds: ['2405.00002']
      }
    ]
  };

  listHomePapers(query: PaperQuery): {
    items: PaperItem[];
    status: string;
    warning?: string;
    emptyReason?: string;
  } {
    let items = [...this.seedPapers];
    if (query.category) {
      items = items.filter((paper: PaperItem) => paper.primaryCategory === query.category);
    }
    if (query.keyword && query.keyword.trim().length > 0) {
      const normalizedKeyword = query.keyword.trim().toLowerCase();
      items = items.filter((paper: PaperItem) => {
        return paper.title.toLowerCase().includes(normalizedKeyword)
          || paper.summary.toLowerCase().includes(normalizedKeyword)
          || paper.authors.join(' ').toLowerCase().includes(normalizedKeyword);
      });
    }
    if (items.length === 0) {
      return {
        items: [],
        status: 'empty',
        warning: query.keyword ? '当前搜索条件没有命中论文。' : '当前时间窗口下暂无论文结果。',
        emptyReason: query.keyword ? 'no_results' : 'time_window_filtered'
      };
    }
    return {
      items,
      status: 'ok'
    };
  }

  getTrendSummary(): TrendSummary {
    return this.seedTrendSummary;
  }

  translatePaper(paper: PaperItem): PaperItem {
    if (paper.translatedSummary && paper.translatedSummary.length > 0) {
      return paper;
    }
    return {
      ...paper,
      translatedSummary: `中文翻译：${paper.summary}`
    };
  }

  listFavorites(): FavoritePaperItem[] {
    return this.seedPapers
      .filter((paper: PaperItem) => paper.favoriteState)
      .map((paper: PaperItem) => {
        return {
          paper,
          savedAt: '2026-05-18'
        };
      });
  }

  exportBibtex(favorites: FavoritePaperItem[]): string {
    return favorites.map((favorite: FavoritePaperItem) => {
      return `@article{${favorite.paper.id},\n  title={${favorite.paper.title}},\n  author={${favorite.paper.authors.join(' and ')}},\n  year={2026}\n}`;
    }).join('\n\n');
  }

  chatWithPapers(papers: FavoritePaperItem[], question: string): {
    answer: string;
    warning?: string;
    usedPapers: PaperChatUsedPaper[];
    messages: PaperChatMessage[];
  } {
    const titles = papers.map((item: FavoritePaperItem) => item.paper.title).join('、');
    return {
      answer: `基于 ${titles}，当前问题“${question}”的回答仍使用前端样例数据生成，后续会替换为真实后端响应。`,
      warning: '当前对话仍是本地样例流程，尚未接入真实后端大模型。',
      usedPapers: papers.map((item: FavoritePaperItem) => {
        return {
          paperId: item.paper.id,
          title: item.paper.title,
          status: 'summary_fallback',
          contextChars: item.paper.summary.length,
          warning: '仅使用论文摘要'
        };
      }),
      messages: [
        {
          role: 'user',
          content: question
        },
        {
          role: 'assistant',
          content: `基于 ${titles} 的当前样例回答已生成。`
        }
      ]
    };
  }

  getIntegrationConfigStatus(): IntegrationConfigPayload {
    return {
      zotero: {
        userId: '123456',
        libraryType: 'user',
        apiKeyMasked: '***1234',
        targetCollectionName: 'XivDaily'
      },
      llm: {
        baseUrl: 'https://grok.yangyioryy.cc.cd',
        model: 'grok-4.20-0309-non-reasoning',
        apiKeyMasked: '***abcd'
      }
    };
  }

  mergeSettingsStatus(previous: SettingsStatus): SettingsStatus {
    const payload = this.getIntegrationConfigStatus();
    return {
      ...previous,
      zoteroConfigured: true,
      zoteroUserId: payload.zotero.userId,
      zoteroLibraryType: payload.zotero.libraryType,
      zoteroApiKeyMasked: payload.zotero.apiKeyMasked,
      zoteroTargetCollectionName: payload.zotero.targetCollectionName,
      zoteroTargetCollectionStatus: 'ready',
      llmConfigured: true,
      llmBaseUrl: payload.llm.baseUrl,
      llmModel: payload.llm.model,
      llmApiKeyMasked: payload.llm.apiKeyMasked,
      integrationStatusFailed: false
    };
  }
}

export default new PaperService();
