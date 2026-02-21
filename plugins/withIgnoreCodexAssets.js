const { createRunOncePlugin, withAppBuildGradle } = require('@expo/config-plugins');

const CODEX_DIR_PATTERN = '!<dir>codex';

function addIgnoreAssetsPattern(contents) {
  const re = /ignoreAssetsPattern\s+(['"])([^'"]*)\1/;
  const match = contents.match(re);
  if (match) {
    const quote = match[1];
    const current = match[2];
    if (current.includes('<dir>codex')) return contents;
    const sep = current.endsWith(':') ? '' : ':';
    const next = `${current}${sep}${CODEX_DIR_PATTERN}`;
    return contents.replace(re, `ignoreAssetsPattern ${quote}${next}${quote}`);
  }

  // Best-effort fallback: insert androidResources block if missing.
  const androidBlock = contents.match(/android\s*\{\s*\n/);
  if (!androidBlock) return contents;
  const insertAt = androidBlock.index + androidBlock[0].length;
  const snippet = `  androidResources {\n    ignoreAssetsPattern '${CODEX_DIR_PATTERN}'\n  }\n\n`;
  return `${contents.slice(0, insertAt)}${snippet}${contents.slice(insertAt)}`;
}

function withIgnoreCodexAssets(config) {
  return withAppBuildGradle(config, (config) => {
    config.modResults.contents = addIgnoreAssetsPattern(config.modResults.contents);
    return config;
  });
}

module.exports = createRunOncePlugin(withIgnoreCodexAssets, 'withIgnoreCodexAssets', '0.0.1');
