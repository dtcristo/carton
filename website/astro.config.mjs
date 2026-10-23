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
  // Pages that moved: first into Start here, Guides, and Reference, then when
  // Start here joined Guides.
  redirects: {
    '/project/why-carton/': '/guides/why-carton/',
    '/project/status/': '/guides/status/',
    '/start/getting-started/': '/guides/getting-started/',
    '/start/why-carton/': '/guides/why-carton/',
    '/start/status/': '/guides/status/',
    '/project/glossary/': '/reference/glossary/',
    '/start/examples/': '/guides/examples/',
    '/guides/examples/rails-in-cartons/': '/guides/examples/rails/',
    '/guides/examples/hanami-in-cartons/': '/guides/examples/hanami/',
  },
  integrations: [
    starlight({
      title: 'Carton',
      description:
        "Ruby apps draw boundaries with folders and namespaces. Ruby ignores them. Carton makes them real. Only a Carton's export crosses, enforced at runtime.",
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
          label: 'Guides',
          items: [
            {
              label: 'Start here',
              items: [
                'guides/getting-started',
                'guides/why-carton',
                'guides/status',
              ],
            },
            {
              label: 'Concepts',
              items: [
                'guides/cartons',
                'guides/exporting',
                'guides/importing',
                'guides/sharing-classes',
              ],
            },
            {
              label: 'How-to',
              items: [
                'guides/adopting',
                'guides/bundler',
                'guides/testing',
                'guides/types-and-checks',
              ],
            },
            { label: 'Examples', items: [{ autogenerate: { directory: 'guides/examples' } }] },
          ],
        },
        {
          label: 'Reference',
          items: [
            {
              label: 'API',
              items: ['reference/kernel', 'reference/carton', 'reference/errors'],
            },
            { label: 'CLI', items: [{ autogenerate: { directory: 'reference/cli' } }] },
            { label: 'Other', items: ['reference/glossary'] },
          ],
        },
      ],
    }),
  ],
});
