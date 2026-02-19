const { createRunOncePlugin, withGradleProperties } = require('@expo/config-plugins');

function withLegacyPackaging(config) {
  return withGradleProperties(config, (config) => {
    // Ensure native libs are packaged in "legacy" mode so they are extracted to the filesystem.
    // This is required if we want to execute bundled ELF binaries from ApplicationInfo.nativeLibraryDir.
    config.modResults = config.modResults.filter((item) => item.key !== 'expo.useLegacyPackaging');
    config.modResults.push({
      type: 'property',
      key: 'expo.useLegacyPackaging',
      value: 'true',
    });
    return config;
  });
}

module.exports = createRunOncePlugin(withLegacyPackaging, 'withLegacyPackaging', '0.0.1');

