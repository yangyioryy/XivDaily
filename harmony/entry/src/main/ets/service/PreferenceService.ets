import { SettingsStatus } from '../model/AppModels';

const SETTINGS_STORAGE_KEY: string = 'xivdaily_settings_storage';

export class PreferenceService {
  initialize(defaultValue: SettingsStatus): void {
    // 先把设置状态放入 PersistentStorage，后续接真实设置页时不需要再改存储入口。
    PersistentStorage.persistProp<SettingsStatus>(SETTINGS_STORAGE_KEY, defaultValue);
    AppStorage.setOrCreate<SettingsStatus>(SETTINGS_STORAGE_KEY, this.read(defaultValue));
  }

  read(defaultValue: SettingsStatus): SettingsStatus {
    const value = AppStorage.get<SettingsStatus>(SETTINGS_STORAGE_KEY);
    if (value === undefined) {
      return defaultValue;
    }
    return value;
  }

  save(nextValue: SettingsStatus): SettingsStatus {
    AppStorage.setOrCreate<SettingsStatus>(SETTINGS_STORAGE_KEY, nextValue);
    return nextValue;
  }
}

export default new PreferenceService();
