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
const carton = /(^\s*|=\s*)(import_relative|import|export)\b/;
// A trailing `# => value` comment is what an example returns, and a trailing
// `# NameError` is what it raises.
const result = /#\s*=>.*$/;
const error = /#\s*[A-Z]\w*(?:::\w+)*(?:Error|Exception)\b.*$/;

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
          const annotations = [];
          const call = line.text.match(carton);
          if (call) {
            const start = call.index + call[1].length;
            annotations.push(...style('call', start, start + call[2].length));
          }
          const raised = line.text.match(error);
          const res = raised ? null : line.text.match(result);
          if (raised) annotations.push(...style('error', raised.index, line.text.length, { bold: true }));
          if (res) annotations.push(...style('result', res.index, line.text.length, { bold: true }));
          for (const a of annotations) line.addAnnotation(a);
        }
      },
    },
  });
