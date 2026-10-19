// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import starlightLinksValidator from 'starlight-links-validator';

export default defineConfig({
  site: 'https://carton.dtcristo.com',
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
      components: {
        Hero: './src/components/Hero.astro',
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
