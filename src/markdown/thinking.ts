type ThinkingSplit = {
  visible: string;
  thinking: string | null;
};

/**
 * 将消息中的思考内容与可见内容分离。
 * 约定：使用 <think>...</think>（兼容 <analysis>...</analysis>）。
 */
export function splitThinking(text: string): ThinkingSplit {
  const normalized = text.replaceAll('<analysis>', '<think>').replaceAll('</analysis>', '</think>');

  const open = '<think>';
  const close = '</think>';

  let cursor = 0;
  const visibleParts: string[] = [];
  const thinkingParts: string[] = [];

  while (cursor < normalized.length) {
    const openIndex = normalized.indexOf(open, cursor);
    if (openIndex === -1) {
      visibleParts.push(normalized.slice(cursor));
      break;
    }

    visibleParts.push(normalized.slice(cursor, openIndex));

    const afterOpen = openIndex + open.length;
    const closeIndex = normalized.indexOf(close, afterOpen);
    if (closeIndex === -1) {
      thinkingParts.push(normalized.slice(afterOpen));
      cursor = normalized.length;
      break;
    }

    thinkingParts.push(normalized.slice(afterOpen, closeIndex));
    cursor = closeIndex + close.length;
  }

  const visible = visibleParts.join('').trim();
  const thinking = thinkingParts.join('\n\n').trim();

  return {
    visible,
    thinking: thinking ? thinking : null,
  };
}

