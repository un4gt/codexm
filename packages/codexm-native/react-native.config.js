module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: './android',
        packageImportPath: 'import com.codexm.nativemodules.CodexMNativePackage;',
        packageInstance: 'new CodexMNativePackage()',
      },
    },
  },
};
