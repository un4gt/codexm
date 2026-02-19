const { createRunOncePlugin, withAndroidManifest } = require('@expo/config-plugins');

function withExtractNativeLibs(config) {
  return withAndroidManifest(config, (config) => {
    const app = config.modResults?.manifest?.application?.[0];
    if (!app) return config;
    app.$ = app.$ ?? {};
    app.$['android:extractNativeLibs'] = 'true';
    return config;
  });
}

module.exports = createRunOncePlugin(withExtractNativeLibs, 'withExtractNativeLibs', '0.0.1');

