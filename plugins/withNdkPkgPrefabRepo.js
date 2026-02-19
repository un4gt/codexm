const { createRunOncePlugin, withProjectBuildGradle, withSettingsGradle } = require('@expo/config-plugins');

const DEFAULT_MAVEN_URL =
  'https://raw.githubusercontent.com/leleliu008/ndk-pkg-prefab-aar-maven-repo/master';

function findMatchingBrace(contents, openBraceIndex) {
  let depth = 0;
  for (let i = openBraceIndex; i < contents.length; i++) {
    const ch = contents[i];
    if (ch === '{') depth++;
    else if (ch === '}') {
      depth--;
      if (depth === 0) return i;
    }
  }
  return -1;
}

function ensureRepoInRepositoriesBlocks(contents, repoLine) {
  const re = /repositories\s*\{\s*\n/g;
  let out = '';
  let lastIndex = 0;
  let match = null;

  while ((match = re.exec(contents)) !== null) {
    const matchStart = match.index;
    const matchEnd = re.lastIndex;

    const openBraceIndex = matchStart + match[0].lastIndexOf('{');
    const closeBraceIndex = findMatchingBrace(contents, openBraceIndex);
    if (closeBraceIndex === -1) continue;

    const blockBody = contents.slice(openBraceIndex + 1, closeBraceIndex);
    const lineStart = contents.lastIndexOf('\n', matchStart) + 1;
    const leading = contents.slice(lineStart, matchStart);
    const indent = leading.match(/^\s*/)?.[0] ?? '';
    const innerIndent = `${indent}  `;

    out += contents.slice(lastIndex, matchEnd);
    if (!blockBody.includes(repoLine)) {
      out += `${innerIndent}${repoLine}\n`;
    }
    lastIndex = matchEnd;
  }

  out += contents.slice(lastIndex);
  return out;
}

function withNdkPkgPrefabRepo(config, props = {}) {
  const url = props.url ?? DEFAULT_MAVEN_URL;
  const repoLine = `maven { url '${url}' }`;

  config = withSettingsGradle(config, (config) => {
    config.modResults.contents = ensureRepoInRepositoriesBlocks(config.modResults.contents, repoLine);
    return config;
  });

  config = withProjectBuildGradle(config, (config) => {
    config.modResults.contents = ensureRepoInRepositoriesBlocks(config.modResults.contents, repoLine);
    return config;
  });

  return config;
}

module.exports = createRunOncePlugin(withNdkPkgPrefabRepo, 'withNdkPkgPrefabRepo', '0.0.1');
