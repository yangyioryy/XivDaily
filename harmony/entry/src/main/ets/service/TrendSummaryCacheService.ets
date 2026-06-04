import { TrendItem, TrendSummary } from '../model/AppModels';

const TREND_SUMMARY_CACHE_STORAGE_KEY: string = 'xivdaily_trend_summary_cache_storage';

interface TrendSummaryCacheEntry {
  key: string;
  savedAt: string;
  trendSummary: TrendSummary;
}

type TrendSummaryCacheMap = Record<string, TrendSummaryCacheEntry>;

export class TrendSummaryCacheService {
  initialize(): void {
    const defaultValue: TrendSummaryCacheMap = {};
    PersistentStorage.persistProp<TrendSummaryCacheMap>(TREND_SUMMARY_CACHE_STORAGE_KEY, defaultValue);
    AppStorage.setOrCreate<TrendSummaryCacheMap>(TREND_SUMMARY_CACHE_STORAGE_KEY, this.readAll());
  }

  read(category?: string, keyword?: string, days: number = 3): TrendSummary | undefined {
    const cache = this.readAll();
    const key = this.buildKey(category, keyword, days);
    const entry = cache[key];
    if (!entry) {
      return undefined;
    }
    return this.cloneTrendSummary(entry.trendSummary);
  }

  save(category: string | undefined, keyword: string | undefined, days: number, trendSummary: TrendSummary): void {
    // 只缓存真正成功的趋势简报，避免把模型不可用时的降级摘要长期固化到本地。
    if (trendSummary.status !== 'success') {
      return;
    }

    const current = this.readAll();
    const nextCache: TrendSummaryCacheMap = {};
    Object.keys(current).forEach((key: string) => {
      nextCache[key] = this.cloneCacheEntry(current[key]);
    });

    const key = this.buildKey(category, keyword, days);
    nextCache[key] = {
      key,
      savedAt: new Date().toISOString(),
      trendSummary: this.cloneTrendSummary(trendSummary)
    };
    AppStorage.setOrCreate<TrendSummaryCacheMap>(TREND_SUMMARY_CACHE_STORAGE_KEY, nextCache);
  }

  private readAll(): TrendSummaryCacheMap {
    const value = AppStorage.get<TrendSummaryCacheMap>(TREND_SUMMARY_CACHE_STORAGE_KEY);
    if (value === undefined) {
      return {};
    }
    return value;
  }

  private buildKey(category?: string, keyword?: string, days: number = 3): string {
    const normalizedCategory = (category ?? '').trim();
    const normalizedKeyword = (keyword ?? '').trim();
    // 后端趋势缓存按 UTC 日期切日，本地缓存也使用 UTC 日期，避免跨时区造成同日 key 不一致。
    const dateKey = new Date().toISOString().slice(0, 10);
    if (normalizedKeyword.length === 0) {
      return `${normalizedCategory.length > 0 ? normalizedCategory : 'all'}:${days}:${dateKey}`;
    }
    return `${normalizedCategory.length > 0 ? normalizedCategory : 'all'}:kw:${this.normalizeCachePart(normalizedKeyword)}:${days}:${dateKey}`;
  }

  private normalizeCachePart(value: string): string {
    const compactValue = value.toLowerCase().split(/\s+/g).filter((part: string) => part.length > 0).join('-');
    let normalized = '';
    for (let index = 0; index < compactValue.length; index += 1) {
      const char = compactValue.charAt(index);
      normalized += /^[a-z0-9_.-]$/.test(char) ? char : '-';
    }
    const limitedValue = normalized.slice(0, 48);
    return limitedValue.length > 0 ? limitedValue : 'keyword';
  }

  private cloneCacheEntry(source: TrendSummaryCacheEntry): TrendSummaryCacheEntry {
    return {
      key: source.key,
      savedAt: source.savedAt,
      trendSummary: this.cloneTrendSummary(source.trendSummary)
    };
  }

  private cloneTrendSummary(source: TrendSummary): TrendSummary {
    const items: TrendItem[] = source.items.map((item: TrendItem): TrendItem => {
      return {
        rank: item.rank,
        trendTitle: item.trendTitle,
        summary: item.summary,
        representativePaperIds: item.representativePaperIds.slice()
      };
    });
    return {
      intro: source.intro,
      items,
      status: source.status,
      warning: source.warning
    };
  }
}

export default new TrendSummaryCacheService();
