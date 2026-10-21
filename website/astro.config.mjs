// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import starlightLinksValidator from 'starlight-links-validator';
import { cartonCode, themes } from './src/expressive-code.mjs';

const SITE = 'https://carton.dtcristo.com';

export default defineConfig({
  site: SITE,
  // Prebuilt HTML only: no adapter, no server runtime.
  output: 'static',
  integrations: [
    starlight({
      title: 'Carton',
      description:
        'Real boundaries for Ruby. Split an app into Cartons that import and export like plain modules, and Ruby enforces the boundary while code runs.',
      logo: { src: './src/assets/carton.png', alt: 'Carton' },
      favicon: '/favicon.png',
      // Share-sheet card for Slack, X, iMessage and friends. Absolute URLs
      // because crawlers do not resolve relative image paths.
      head: [
        { tag: 'meta', attrs: { property: 'og:image', content: `${SITE}/og-image.png` } },
        { tag: 'meta', attrs: { property: 'og:image:width', content: '1200' } },
        { tag: 'meta', attrs: { property: 'og:image:height', content: '630' } },
        { tag: 'meta', attrs: { property: 'og:image:alt', content: 'Carton: Real boundaries for Ruby' } },
        { tag: 'meta', attrs: { name: 'twitter:card', content: 'summary_large_image' } },
        { tag: 'meta', attrs: { name: 'twitter:image', content: `${SITE}/og-image.png` } },
      ],
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/dtcristo/carton',
        },
      ],
      editLink: {
        baseUrl: 'https://github.com/dtcristo/carton/edit/main/website/',
      },
      customCss: ['./src/styles/theme.css'],
      // Code cards follow the Ruby::Box talk: a filename tab from a leading
      // `# path` comment or a `title`, and shell commands on a dark card.
      expressiveCode: {
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
      },
      components: {
        Hero: './src/components/Hero.astro',
        SocialIcons: './src/components/SocialIcons.astro',
        Sidebar: './src/components/Sidebar.astro',
      },
      plugins: [starlightLinksValidator()],
      sidebar: [
        { label: 'Start here', items: [{ autogenerate: { directory: 'start' } }] },
        { label: 'Guides', items: [{ autogenerate: { directory: 'guides' } }] },
        {
          label: 'Reference',
          items: [
            {
              label: 'API',
              items: [
                'reference/carton',
                'reference/namespace',
                'reference/kernel',
                'reference/errors',
              ],
            },
            { label: 'CLI', items: ['reference/cli'] },
          ],
        },
        { label: 'Project', items: [{ autogenerate: { directory: 'project' } }] },
      ],
    }),
  ],
});
