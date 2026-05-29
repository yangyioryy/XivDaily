export type XivResolvedThemeMode = 'light' | 'dark';
export type XivThemeModePreference = 'light' | 'dark' | 'system';

export interface XivThemePalette {
  background: string;
  surface: string;
  surfaceVariant: string;
  surfaceSubtle: string;
  secondaryContainer: string;
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  primary: string;
  onPrimary: string;
  primaryContainer: string;
  onPrimaryContainer: string;
  onSecondaryContainer: string;
  outline: string;
  divider: string;
  success: string;
  successContainer: string;
  warning: string;
  warningContainer: string;
  danger: string;
  dangerContainer: string;
  info: string;
  overlay: string;
}

const LIGHT_PALETTE: XivThemePalette = {
  background: '#F7F9FD',
  surface: '#FFFFFF',
  surfaceVariant: '#F1F4F9',
  surfaceSubtle: '#F8FAFC',
  secondaryContainer: '#F1F4FA',
  textPrimary: '#111827',
  textSecondary: '#6B7280',
  textTertiary: '#374151',
  primary: '#2D6CE8',
  onPrimary: '#FFFFFF',
  primaryContainer: '#EAF2FF',
  onPrimaryContainer: '#1648A8',
  onSecondaryContainer: '#263244',
  outline: '#D7DEE9',
  divider: '#EEF2F7',
  success: '#3F7A58',
  successContainer: '#EAF7EF',
  warning: '#B37B3F',
  warningContainer: '#FFF1DD',
  danger: '#B6544A',
  dangerContainer: '#FFEAEA',
  info: '#456E9E',
  overlay: '#66000000'
};

const DARK_PALETTE: XivThemePalette = {
  background: '#10141B',
  surface: '#161C24',
  surfaceVariant: '#222B37',
  surfaceSubtle: '#1B232D',
  secondaryContainer: '#374458',
  textPrimary: '#F5F7FB',
  textSecondary: '#B7C0CF',
  textTertiary: '#C3CEDC',
  primary: '#9CC2FF',
  onPrimary: '#0D2452',
  primaryContainer: '#183B82',
  onPrimaryContainer: '#EAF2FF',
  onSecondaryContainer: '#F1F4FA',
  outline: '#4E5868',
  divider: '#2A3442',
  success: '#7FD09D',
  successContainer: '#183526',
  warning: '#F5C98A',
  warningContainer: '#4F3A1A',
  danger: '#F2A8A2',
  dangerContainer: '#542A2A',
  info: '#9CC2FF',
  overlay: '#7A000000'
};

function isDarkSystemColorMode(systemColorMode?: string | number): boolean {
  if (typeof systemColorMode === 'number') {
    return systemColorMode === 2;
  }
  if (systemColorMode === undefined) {
    return false;
  }
  const normalizedValue = `${systemColorMode}`.trim().toLowerCase();
  return normalizedValue === '2' || normalizedValue === 'dark' || normalizedValue.includes('dark');
}

export function normalizeXivThemeMode(themeMode?: string): XivThemeModePreference {
  const normalizedValue = `${themeMode ?? ''}`.trim().toLowerCase();
  if (normalizedValue === 'dark' || normalizedValue.endsWith('_dark') || normalizedValue.includes('dark')) {
    return 'dark';
  }
  if (normalizedValue === 'light' || normalizedValue.endsWith('_light') || normalizedValue.includes('light')) {
    return 'light';
  }
  if (normalizedValue === 'system'
    || normalizedValue === 'auto'
    || normalizedValue === 'follow_system'
    || normalizedValue === 'follow-system'
    || normalizedValue.includes('system')
    || normalizedValue.includes('auto')) {
    return 'system';
  }
  return 'system';
}

export function resolveXivThemeMode(themeMode: string, systemColorMode?: string | number): XivResolvedThemeMode {
  const normalizedThemeMode = normalizeXivThemeMode(themeMode);
  if (normalizedThemeMode === 'dark') {
    return 'dark';
  }
  if (normalizedThemeMode === 'light') {
    return 'light';
  }
  // 系统主题值在 ArkUI 里可能是枚举数字，也可能被桥接成字符串，这里统一做一层归一化。
  return isDarkSystemColorMode(systemColorMode) ? 'dark' : 'light';
}

export function resolveXivPalette(themeMode: string, systemColorMode?: string | number): XivThemePalette {
  // 全站页面都通过同一套调色板解析，避免个别页面在主题切换后残留浅色硬编码。
  return resolveXivThemeMode(themeMode, systemColorMode) === 'dark' ? DARK_PALETTE : LIGHT_PALETTE;
}
