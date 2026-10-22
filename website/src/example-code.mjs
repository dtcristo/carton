import { dirname, resolve } from 'node:path';

/** @param {string} source @param {{ file: string, carton: string }} paths */
export function exampleCode(source, paths) {
  const code = source.replace(/^# frozen_string_literal: true\n\n?/, '').trimEnd();
  let loading = true;

  return code.split('\n').map((line) => {
    if (!loading || /^\s*(?:#.*)?$/.test(line)) return line;
    // Only inspect the leading literal requires, never Ruby strings or bodies.
    const call = line.match(/^([ \t]*)(require|require_relative)[ \t]+(['"])([^'"]+)\3([ \t]*(?:#.*)?)$/);
    if (!call) {
      loading = false;
      return line;
    }

    const [, indent, method, , path, comment] = call;
    const target = resolve(dirname(paths.file), path);
    if (method === 'require_relative' && (target === paths.carton || `${target}.rb` === paths.carton)) {
      return `${indent}require 'carton'${comment}`;
    }
    return line;
  }).join('\n');
}
