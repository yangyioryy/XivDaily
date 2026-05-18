import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import window from '@ohos.window';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage) {
    // 入口能力只负责加载首页，避免把页面状态和生命周期逻辑堆进 Ability。
    windowStage.loadContent('pages/XivDailyPage', (err, data) => {
      if (err.code) {
        hilog.error(0x0000, 'XivDaily', 'Failed to load content: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'XivDaily', 'Succeeded in loading content: %{public}s', JSON.stringify(data) ?? '');
    });
  }
}
