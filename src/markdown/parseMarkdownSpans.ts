import type { MarkdownSpan } from './types';

const pattern = /(\*\*(.*?)(?:\*\*|$))|(\*(.*?)(?:\*|$))|(\[([^\]]+)\](?:\(([^)]+)\))?)|(`(.*?)(?:`|$))/g;

export function parseMarkdownSpans(markdown: string, header: boolean): MarkdownSpan[] {
  const spans: MarkdownSpan[] = [];
  let lastIndex = 0;

  pattern.lastIndex = 0;
  let match: RegExpExecArray | null;

  while ((match = pattern.exec(markdown)) !== null) {
    const plainText = markdown.slice(lastIndex, match.index);
    if (plainText) spans.push({ styles: [], text: plainText, url: null });

    if (match[1]) {
      // Bold
      spans.push({ styles: header ? [] : ['bold'], text: match[2], url: null });
    } else if (match[3]) {
      // Italic
      spans.push({ styles: header ? [] : ['italic'], text: match[4], url: null });
    } else if (match[5]) {
      // Link - allow incomplete links ([text] without URL)
      if (match[7]) spans.push({ styles: [], text: match[6], url: match[7] });
      else spans.push({ styles: [], text: `[${match[6]}]`, url: null });
    } else if (match[8]) {
      // Inline code
      spans.push({ styles: ['code'], text: match[9], url: null });
    }

    lastIndex = pattern.lastIndex;
  }

  if (lastIndex < markdown.length) {
    spans.push({ styles: [], text: markdown.slice(lastIndex), url: null });
  }

  return spans;
}
