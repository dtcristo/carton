// Writes the Glossary page from the repository's CONTEXT.md, so the site
// never drifts from it. Runs before `astro dev` and `astro build`.
import { readFileSync, writeFileSync } from 'node:fs';

const root = new URL('../../', import.meta.url);
const context = readFileSync(new URL('CONTEXT.md', root), 'utf8');
const [, language] = context.split(/^## Language$/m);
if (!language) throw new Error('CONTEXT.md has no "## Language" section');

const page = `---
title: Glossary
description: The terms Carton's docs and code use, and the words they avoid.
editUrl: https://github.com/dtcristo/carton/edit/main/CONTEXT.md
sidebar:
  order: 3
---

{/* Generated from CONTEXT.md by scripts/glossary.mjs. Edit that file instead. */}

These are the words Carton's docs, code, and errors use. Each entry lists the words to avoid.
${language.replaceAll(/^### /gm, '## ')}`;

writeFileSync(
  new URL('src/content/docs/project/glossary.mdx', new URL('../', import.meta.url)),
  page,
);
