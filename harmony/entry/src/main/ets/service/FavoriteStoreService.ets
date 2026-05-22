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
      return this.sortFavorites(seedFavorites);
    }
    return this.sortFavorites(value);
  }

  saveFavorite(paper: PaperItem): FavoritePaperItem[] {
    const current = this.read();
    const existed = current.find((item: FavoritePaperItem) => item.paper.id === paper.id);

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
    const savedAt = new Date().toISOString();
    const nextFavorite: FavoritePaperItem = {
      paper: favoritePaper,
      savedAt
    };
    const nextFavorites: FavoritePaperItem[] = existed
      ? current.map((item: FavoritePaperItem) => item.paper.id === paper.id ? nextFavorite : item)
      : current.concat([nextFavorite]);
    const sortedFavorites = this.sortFavorites(nextFavorites);
    AppStorage.setOrCreate<FavoritePaperItem[]>(FAVORITE_STORAGE_KEY, sortedFavorites);
    return sortedFavorites;
  }

  deleteFavorite(paperId: string): FavoritePaperItem[] {
    const nextFavorites = this.sortFavorites(this.read().filter((item: FavoritePaperItem) => item.paper.id !== paperId));
    AppStorage.setOrCreate<FavoritePaperItem[]>(FAVORITE_STORAGE_KEY, nextFavorites);
    return nextFavorites;
  }

  private sortFavorites(favorites: FavoritePaperItem[]): FavoritePaperItem[] {
    return favorites.slice().sort((left: FavoritePaperItem, right: FavoritePaperItem) => {
      return this.savedAtToMillis(right.savedAt) - this.savedAtToMillis(left.savedAt);
    });
  }

  private savedAtToMillis(savedAt: string): number {
    const parsedValue = Date.parse(savedAt);
    if (!Number.isNaN(parsedValue)) {
      return parsedValue;
    }
    const legacyParsedValue = Date.parse(`${savedAt}T00:00:00.000Z`);
    if (!Number.isNaN(legacyParsedValue)) {
      return legacyParsedValue;
    }
    return 0;
  }
}

export default new FavoriteStoreService();
