export type MarkdownSpanStyle = 'bold' | 'italic' | 'code';

export type MarkdownSpan = {
  text: string;
  styles: MarkdownSpanStyle[];
  url: string | null;
};

export type MarkdownBlock =
  | { type: 'header'; level: 1 | 2 | 3 | 4 | 5 | 6; content: MarkdownSpan[] }
  | { type: 'text'; content: MarkdownSpan[] }
  | { type: 'list'; items: MarkdownSpan[][] }
  | { type: 'numbered-list'; items: { number: number; spans: MarkdownSpan[] }[] }
  | { type: 'code-block'; language: string | null; content: string }
  | { type: 'horizontal-rule' }
  | { type: 'blockquote'; content: MarkdownSpan[] };

