import { FavoritePaperItem, PaperItem } from '../model/AppModels';

const FAVORITE_STORAGE_KEY: string = 'xivdaily_favorite_storage';

export class FavoriteStoreService {
  initialize(seedFavorites: FavoritePaperItem[]): void {
    PersistentStorage.persistProp<FavoritePaperItem[]>(FAVORITE_STORAGE_KEY, seedFavorites);
    AppStorage.setOrCreate<FavoritePaperItem[]>(FAVORITE_STORAGE_KEY, this.read(seedFavorites));
  }

  read(seedFavorites: FavoritePaperItem[] = []): FavoritePaperItem[] {
    const value = AppStorage.get<FavoritePaperItem[]>(FAVORITE_STORAGE_KEY);
    if (value === undefined) {
      return seedFavorites;
    }
    return value;
  }

  saveFavorite(paper: PaperItem): FavoritePaperItem[] {
    const current = this.read();
    const existed = current.find((item: FavoritePaperItem) => item.paper.id === paper.id);
    if (existed) {
      return current;
    }

    const favoritePaper: PaperItem = {
      id: paper.id,
      title: paper.title,
      authors: paper.authors,
      summary: paper.summary,
      translatedSummary: paper.translatedSummary,
      publishedAt: paper.publishedAt,
      updatedAt: paper.updatedAt,
      primaryCategory: paper.primaryCategory,
      sourceUrl: paper.sourceUrl,
      pdfUrl: paper.pdfUrl,
      favoriteState: true,
      zoteroSyncState: paper.zoteroSyncState
    };
    const nextFavorite: FavoritePaperItem = {
      paper: favoritePaper,
      savedAt: new Date().toISOString().slice(0, 10)
    };
    const nextFavorites: FavoritePaperItem[] = current.concat([nextFavorite]);
    AppStorage.setOrCreate<FavoritePaperItem[]>(FAVORITE_STORAGE_KEY, nextFavorites);
    return nextFavorites;
  }

  deleteFavorite(paperId: string): FavoritePaperItem[] {
    const nextFavorites = this.read().filter((item: FavoritePaperItem) => item.paper.id !== paperId);
    AppStorage.setOrCreate<FavoritePaperItem[]>(FAVORITE_STORAGE_KEY, nextFavorites);
    return nextFavorites;
  }
}

export default new FavoriteStoreService();
