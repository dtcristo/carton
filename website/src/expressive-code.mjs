// Code blocks, inspired by the Ruby::Box talk's deck: bold ruby keywords, blue
// constants, purple calls, and green strings. A `# => value` result is bold ink
// and a raised `# SomeError` is bold ruby. Every colour keeps 4.5:1 contrast on
// the code card and on the page.
import { definePlugin, InlineStyleAnnotation } from '@astrojs/starlight/expressive-code';

const palettes = {
  light: {
    text: '#1f1b18',
    comment: '#8a6528',
    keyword: '#b3261f',
    method: '#9e2520',
    call: '#6d4aa8',
    constant: '#1f5fa8',
    string: '#2f7a55',
    symbol: '#0e6f7c',
    literal: '#b23c0a',
    operator: '#776e64',
    result: '#1f1b18',
    error: '#b3261f',
  },
  dark: {
    text: '#ece5d7',
    comment: '#c9a065',
    keyword: '#f07a6f',
    method: '#f4a39c',
    call: '#bba3ea',
    constant: '#82b4ec',
    string: '#8fcfa6',
    symbol: '#6fcfdc',
    literal: '#f2a06a',
    operator: '#a39a8d',
    result: '#f8f5ee',
    error: '#f07a6f',
  },
};

const theme = (type) => {
  const c = palettes[type];
  return {
    name: `carton-${type}`,
    type,
    colors: { 'editor.foreground': c.text, 'editor.background': type === 'light' ? '#fffdf9' : '#2f2a25' },
    tokenColors: [
      { scope: ['comment', 'punctuation.definition.comment'], settings: { foreground: c.comment } },
      { scope: ['keyword', 'storage'], settings: { foreground: c.keyword, fontStyle: 'bold' } },
      { scope: ['keyword.operator'], settings: { foreground: c.operator, fontStyle: '' } },
      {
        scope: ['keyword.other.special-method', 'support.function', 'meta.function-call entity.name.function'],
        settings: { foreground: c.call, fontStyle: '' },
      },
      { scope: ['meta.function.method entity.name.function', 'entity.name.function'], settings: { foreground: c.method, fontStyle: 'bold' } },
      { scope: ['support.class', 'variable.other.constant', 'entity.name.type'], settings: { foreground: c.constant } },
      { scope: ['entity.name.type.class', 'entity.name.type.module'], settings: { foreground: c.constant, fontStyle: 'bold' } },
      { scope: ['string', 'string.definition'], settings: { foreground: c.string } },
      { scope: ['constant.language.symbol', 'constant.other.symbol'], settings: { foreground: c.symbol } },
      { scope: ['constant.numeric', 'constant.language'], settings: { foreground: c.literal } },
      { scope: ['variable.other.readwrite.instance'], settings: { foreground: c.text } },
      { scope: ['punctuation', 'meta.flow-sequence'], settings: { foreground: c.operator } },
      { scope: ['entity.name.tag'], settings: { foreground: c.constant } },
    ],
  };
};

export const themes = [theme('dark'), theme('light')];

// Ruby's grammar leaves Carton's own methods as plain text when they are
// called without parentheses, so colour them as calls. `export` and the
// imports only count at the start of a line or after an assignment.
const carton = /(^\s*|=\s*)(import_relative|import|export)\b/g;
// A trailing `# => value` comment is what an example returns, and a trailing
// `# NameError` is what it raises.
const result = /^#\s*=>/;
const error = /^#\s*[A-Z]\w*(?:::\w+)*(?:Error|Exception)\b/;

// Splits a line of Ruby into its code and its trailing comment, skipping
// quoted strings, so a `#` or `import` inside a string never counts.
const scan = (text) => {
  const strings = [];
  let quote = null;
  let opened = 0;
  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (quote) {
      if (char === '\\') i++;
      else if (char === quote) {
        strings.push([opened, i + 1]);
        quote = null;
      }
    } else if (char === "'" || char === '"') {
      quote = char;
      opened = i;
    } else if (char === '#') {
      return { strings, comment: i };
    }
  }
  if (quote) strings.push([opened, text.length]);
  return { strings, comment: text.length };
};

// The ranges to restyle in one line: Carton calls, and a result or error.
export const marks = (text) => {
  const { strings, comment } = scan(text);
  const inString = (i) => strings.some(([a, b]) => i >= a && i < b);
  const found = [];
  for (const call of text.slice(0, comment).matchAll(carton)) {
    const start = call.index + call[1].length;
    if (!inString(start)) found.push({ key: 'call', start, end: start + call[2].length });
  }
  const tail = text.slice(comment);
  if (error.test(tail)) found.push({ key: 'error', start: comment, end: text.length, bold: true });
  else if (result.test(tail)) found.push({ key: 'result', start: comment, end: text.length, bold: true });
  return found;
};

const style = (key, start, end, extra = {}) =>
  themes.map(
    (t, styleVariantIndex) =>
      new InlineStyleAnnotation({
        inlineRange: { columnStart: start, columnEnd: end },
        color: palettes[t.type][key],
        styleVariantIndex,
        renderPhase: 'latest',
        ...extra,
      }),
  );

export const cartonCode = () =>
  definePlugin({
    name: 'carton-code',
    hooks: {
      postprocessAnalyzedCode: ({ codeBlock }) => {
        if (codeBlock.language !== 'ruby') return;
        for (const line of codeBlock.getLines()) {
          for (const { key, start, end, bold } of marks(line.text)) {
            for (const a of style(key, start, end, { bold })) line.addAnnotation(a);
          }
        }
      },
    },
  });
