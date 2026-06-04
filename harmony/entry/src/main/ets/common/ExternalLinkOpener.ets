import { Want } from '@kit.AbilityKit';
import common from '@ohos.app.ability.common';

export class ExternalLinkOpener {
  static async open(hostContext: common.UIAbilityContext, rawUrl: string): Promise<void> {
    const targetUrl = ExternalLinkOpener.normalizeHttpUrl(rawUrl);
    const browserWant: Want = {
      action: 'ohos.want.action.viewData',
      uri: targetUrl,
      entities: ['entity.system.browsable']
    };

    try {
      // Prefer the browser Want path for normal web pages.
      await hostContext.startAbility(browserWant);
    } catch (error) {
      await hostContext.openLink(targetUrl);
    }
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
