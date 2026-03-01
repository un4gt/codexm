import type { MarkdownBlock } from './types';
import { parseMarkdownSpans } from './parseMarkdownSpans';

function isHeaderLine(line: string) {
  for (let level = 1; level <= 6; level++) {
    if (line.startsWith(`${'#'.repeat(level)} `)) {
      return level as 1 | 2 | 3 | 4 | 5 | 6;
    }
  }
  return null;
}

function isNumberedListLine(trimmed: string) {
  return trimmed.match(/^(\d+)\.\s+/);
}

function isBulletListLine(trimmed: string) {
  return trimmed.match(/^[-*]\s+/);
}

function isHr(trimmed: string) {
  return trimmed === '---' || trimmed === '***';
}

function isBlockStart(trimmed: string) {
  if (!trimmed) return false;
  return (
    Boolean(isHeaderLine(trimmed)) ||
    trimmed.startsWith('```') ||
    trimmed.startsWith('>') ||
    Boolean(isBulletListLine(trimmed)) ||
    Boolean(isNumberedListLine(trimmed)) ||
    isHr(trimmed)
  );
}

export function parseMarkdownBlock(markdown: string): MarkdownBlock[] {
  const blocks: MarkdownBlock[] = [];
  const lines = markdown.split('\n');

  let index = 0;
  outer: while (index < lines.length) {
    const line = lines[index];
    index++;

    const headerLevel = isHeaderLine(line);
    if (headerLevel) {
      blocks.push({
        type: 'header',
        level: headerLevel,
        content: parseMarkdownSpans(line.slice(headerLevel + 1).trim(), true),
      });
      continue outer;
    }

    const trimmed = line.trim();
    if (!trimmed) continue;

    // Code block
    if (trimmed.startsWith('```')) {
      const language = trimmed.slice(3).trim() || null;
      const contentLines: string[] = [];

      while (index < lines.length) {
        const nextLine = lines[index];
        if (nextLine.trim() === '```') {
          index++;
          break;
        }
        contentLines.push(nextLine);
        index++;
      }

      blocks.push({
        type: 'code-block',
        language,
        content: contentLines.join('\n'),
      });
      continue outer;
    }

    // Horizontal rule
    if (isHr(trimmed)) {
      blocks.push({ type: 'horizontal-rule' });
      continue outer;
    }

    // Blockquote
    if (trimmed.startsWith('>')) {
      const quoteLines: string[] = [trimmed.replace(/^>\s?/, '')];
      while (index < lines.length) {
        const nextTrimmed = lines[index].trim();
        if (!nextTrimmed.startsWith('>')) break;
        quoteLines.push(nextTrimmed.replace(/^>\s?/, ''));
        index++;
      }
      const quote = quoteLines.join('\n').trim();
      if (quote) blocks.push({ type: 'blockquote', content: parseMarkdownSpans(quote, false) });
      continue outer;
    }

    // Numbered list
    const numberedListMatch = isNumberedListLine(trimmed);
    if (numberedListMatch) {
      const firstNumber = Number.parseInt(numberedListMatch[1] ?? '1', 10);
      const items: { number: number; spans: ReturnType<typeof parseMarkdownSpans> }[] = [
        { number: Number.isFinite(firstNumber) ? firstNumber : 1, spans: parseMarkdownSpans(trimmed.slice(numberedListMatch[0].length), false) },
      ];

      while (index < lines.length) {
        const nextTrimmed = lines[index].trim();
        const nextMatch = isNumberedListLine(nextTrimmed);
        if (!nextMatch) break;

        const n = Number.parseInt(nextMatch[1] ?? '1', 10);
        items.push({
          number: Number.isFinite(n) ? n : 1,
          spans: parseMarkdownSpans(nextTrimmed.slice(nextMatch[0].length), false),
        });
        index++;
      }

      blocks.push({ type: 'numbered-list', items });
      continue outer;
    }

    // Bullet list
    const bulletMatch = isBulletListLine(trimmed);
    if (bulletMatch) {
      const items: ReturnType<typeof parseMarkdownSpans>[] = [parseMarkdownSpans(trimmed.slice(bulletMatch[0].length), false)];
      while (index < lines.length) {
        const nextTrimmed = lines[index].trim();
        const nextBullet = isBulletListLine(nextTrimmed);
        if (!nextBullet) break;
        items.push(parseMarkdownSpans(nextTrimmed.slice(nextBullet[0].length), false));
        index++;
      }
      blocks.push({ type: 'list', items });
      continue outer;
    }

    // Paragraph: merge consecutive plain-text lines until next block
    const paragraphLines: string[] = [trimmed];
    while (index < lines.length) {
      const nextLine = lines[index];
      const nextTrimmed = nextLine.trim();
      if (!nextTrimmed) {
        index++;
        break;
      }
      if (isBlockStart(nextTrimmed)) break;
      paragraphLines.push(nextTrimmed);
      index++;
    }

    const paragraph = paragraphLines.join('\n').trim();
    if (paragraph) blocks.push({ type: 'text', content: parseMarkdownSpans(paragraph, false) });
  }

  return blocks;
}

