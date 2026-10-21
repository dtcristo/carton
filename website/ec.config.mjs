// @ts-check
// Code cards follow the Ruby::Box talk: a filename tab from a leading `# path`
// comment or a `title`, and shell commands on a dark card. These options live
// here, not in astro.config.mjs, so the <Code> component can load them.
import { defineEcConfig } from '@astrojs/starlight/expressive-code';
import { cartonCode, themes } from './src/expressive-code.mjs';

export default defineEcConfig({
  themes,
  plugins: [cartonCode()],
  useStarlightUiThemeColors: false,
  minSyntaxHighlightingColorContrast: 4.5,
  defaultProps: {
    overridesByLang: { sh: { frame: 'none' } },
  },
  styleOverrides: {
    borderRadius: '0.9rem',
    borderColor: 'var(--carton-line)',
    borderWidth: '1px',
    codeBackground: 'var(--carton-card)',
    codeFontFamily: 'var(--sl-font-mono)',
    codeFontSize: '0.875rem',
    codeLineHeight: '1.65',
    codePaddingBlock: '1.1rem',
    codePaddingInline: '1.35rem',
    uiFontFamily: 'var(--sl-font-mono)',
    frames: {
      frameBoxShadowCssValue: 'var(--carton-shadow)',
      editorTabBarBackground: 'var(--carton-tab)',
      editorTabBarBorderBottomColor: 'var(--carton-line)',
      editorActiveTabBackground: 'var(--carton-tab)',
      editorActiveTabForeground: 'var(--carton-ink-soft)',
      editorActiveTabBorderColor: 'transparent',
      editorActiveTabIndicatorTopColor: 'transparent',
      editorActiveTabIndicatorBottomColor: 'transparent',
      editorTabBorderRadius: '0',
      terminalTitlebarBackground: 'var(--carton-tab)',
      terminalTitlebarBorderBottomColor: 'var(--carton-line)',
      terminalBackground: 'var(--carton-card)',
      inlineButtonBackground: 'var(--carton-ink-soft)',
      inlineButtonForeground: 'var(--carton-ink-soft)',
      inlineButtonBorder: 'var(--carton-line)',
    },
  },
});
