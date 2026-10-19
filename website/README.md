# Carton website

The website and documentation for Carton, built with [Astro](https://astro.build) and [Starlight](https://starlight.astro.build), served at [carton.dtcristo.com](https://carton.dtcristo.com) by Cloudflare Workers as static assets.

## Develop

Node is pinned in the repository's `.mise.toml`. From this directory:

```sh
npm install
npm run dev      # http://localhost:4321
npm run build    # writes dist/ and checks every internal link
npm run preview  # serves dist/
```

## Layout

- `src/content/docs/`: every page, as Markdown. The sidebar groups follow its directories: `start/`, `guides/`, `reference/`, `project/`.
- `src/content/docs/index.mdx`: the homepage, built from components in `src/components/`.
- `src/styles/theme.css`: colours and type.
- `scripts/glossary.mjs`: writes the Glossary page from the repository's `CONTEXT.md` before each build, so edit `CONTEXT.md`, not the page.

The reference pages are written by hand. Check them against `sig/carton.rbs` and the code when the API changes.

## Deploy

`.github/workflows/website.yml` builds the site for every change, and deploys it from `main` with `wrangler deploy` (configured by `wrangler.jsonc`). One-time setup:

1. Create a Cloudflare API token from the **Edit Cloudflare Workers** template, scoped to the account and the `dtcristo.com` zone.
2. In the GitHub repository settings, create an environment named `website`, limited to the `main` branch, with secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
3. Merge to `main`, or run the workflow by hand. The first deploy creates the `carton` Worker and attaches the `carton.dtcristo.com` custom domain.

Moving to another domain later means adding its route to `wrangler.jsonc` and updating `site` in `astro.config.mjs`.
