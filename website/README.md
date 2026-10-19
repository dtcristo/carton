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

The site is static assets only: `wrangler.jsonc` has no Worker script, no Node.js compatibility, and no routes, and Astro builds plain HTML. `.github/workflows/website.yml` builds the site for every change and deploys it from `main` with `wrangler deploy`, which only uploads `dist/` to the existing `carton` Worker.

The Worker and its `carton.dtcristo.com` custom domain were created once and live in Cloudflare, so the deploy token can be narrow. One-time setup:

1. Create the `carton` Worker and attach the custom domain, from the Cloudflare dashboard (Workers & Pages) or with a one-off local `wrangler deploy` that has a broader login.
2. Create an account-owned API token (Manage Account, Account API Tokens) scoped to the specified Worker `carton`, with the **Editor** role. It needs no zone permissions and cannot create Workers.
3. In the GitHub repository settings, create an environment named `website`, limited to the `main` branch, with secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.

Moving to another domain later means attaching it in the dashboard and updating `site` in `astro.config.mjs`.
