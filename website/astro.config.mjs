// @ts-check
import { defineConfig } from 'astro/config';
import { fileURLToPath } from 'node:url';
import starlight from '@astrojs/starlight';
import starlightLinksValidator from 'starlight-links-validator';

const SITE = 'https://carton.dtcristo.com';

export default defineConfig({
  site: SITE,
  // Prebuilt HTML only: no adapter, no server runtime.
  output: 'static',
  // The repository's examples/, which src/components/ExampleFile.astro reads.
  vite: {
    define: {
      'import.meta.env.EXAMPLES_DIR': JSON.stringify(fileURLToPath(new URL('../examples/', import.meta.url))),
    },
  },
  // Pages that moved when the sections became Start here, Guides, and Reference.
  redirects: {
    '/project/why-carton/': '/start/why-carton/',
    '/project/status/': '/start/status/',
    '/project/glossary/': '/reference/glossary/',
    '/start/examples/': '/guides/examples/',
    '/guides/examples/rails-with-carton-domain/': '/guides/rails/',
    '/guides/examples/rails-in-cartons/': '/guides/examples/rails/',
    '/guides/examples/hanami-in-cartons/': '/guides/examples/hanami/',
  },
  integrations: [
    starlight({
      title: 'Carton',
      description:
        'Split your app into Cartons with explicit imports and exports. Each has its own dependencies and runs in a separate Ruby::Box, so Ruby enforces the boundaries at runtime.',
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
      components: {
        Hero: './src/components/Hero.astro',
        SocialIcons: './src/components/SocialIcons.astro',
        Sidebar: './src/components/Sidebar.astro',
        Head: './src/components/Head.astro',
        Search: './src/components/Search.astro',
        ThemeSelect: './src/components/ThemeSelect.astro',
      },
      plugins: [starlightLinksValidator()],
      // Three sections, each a tab in src/components/Sidebar.astro, which
      // shows only the selected section's tree.
      sidebar: [
        {
          label: 'Start here',
          items: [
            {
              label: 'Start here',
              items: [
                'start/getting-started',
                'start/why-carton',
                'start/status',
              ],
            },
          ],
        },
        {
          label: 'Guides',
          items: [
            {
              label: 'Concepts',
              items: [
                'guides/cartons',
                'guides/exporting',
                'guides/importing',
                'guides/bare-cartons',
                'guides/sharing-classes',
              ],
            },
            {
              label: 'How-to',
              items: ['guides/bundler', 'guides/testing', 'guides/types-and-checks', 'guides/rails'],
            },
            { label: 'Examples', items: [{ autogenerate: { directory: 'guides/examples' } }] },
          ],
        },
        {
          label: 'Reference',
          items: [
            {
              label: 'API',
              items: ['reference/kernel', 'reference/carton', 'reference/namespace', 'reference/errors'],
            },
            { label: 'CLI', items: [{ autogenerate: { directory: 'reference/cli' } }] },
            'reference/glossary',
          ],
        },
      ],
    }),
  ],
});
