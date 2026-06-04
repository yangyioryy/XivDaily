import router from '@ohos.router';

export class ExternalLinkOpener {
  static async open(rawUrl: string, title?: string): Promise<void> {
    const targetUrl = ExternalLinkOpener.normalizeHttpUrl(rawUrl);

    await router.pushUrl({
      url: 'pages/PaperWebPage',
      params: {
        url: targetUrl,
        title: title ?? '论文原文'
      }
    });
  }

  private static normalizeHttpUrl(rawUrl: string): string {
    const targetUrl = rawUrl.trim();
    const lowerUrl = targetUrl.toLowerCase();
    if (!lowerUrl.startsWith('https://') && !lowerUrl.startsWith('http://')) {
      throw new Error('Only http and https links can be opened externally.');
    }
    return targetUrl;
  }
}
