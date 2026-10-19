// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import starlightLinksValidator from 'starlight-links-validator';

export default defineConfig({
  site: 'https://carton.dtcristo.com',
  // Prebuilt HTML only: no adapter, no server runtime.
  output: 'static',
  integrations: [
    starlight({
      title: 'Carton',
      description:
        'Real boundaries for Ruby: Cartons import and export like modules, and Ruby enforces the boundary while the code runs.',
      logo: { src: './src/assets/carton.png', alt: 'Carton' },
      favicon: '/favicon.png',
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
      // Rosé Pine's violet-tinted palette sits with the ruby theme where
      // Starlight's blue and purple tokens did not; panels use the site's own.
      expressiveCode: {
        themes: ['rose-pine', 'rose-pine-dawn'],
        defaultProps: { frame: 'none' },
        styleOverrides: {
          borderRadius: '0.6rem',
          borderColor: 'var(--carton-panel-edge)',
          codeBackground: 'var(--carton-panel)',
          codeFontFamily: 'var(--sl-font-mono)',
          codeFontSize: '0.875rem',
        },
      },
      components: {
        Hero: './src/components/Hero.astro',
        SocialIcons: './src/components/SocialIcons.astro',
      },
      plugins: [starlightLinksValidator()],
      sidebar: [
        { label: 'Start here', items: [{ autogenerate: { directory: 'start' } }] },
        { label: 'Guides', items: [{ autogenerate: { directory: 'guides' } }] },
        { label: 'Reference', items: [{ autogenerate: { directory: 'reference' } }] },
        { label: 'Project', items: [{ autogenerate: { directory: 'project' } }] },
      ],
    }),
  ],
});
