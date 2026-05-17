// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'CodexM';

  @override
  String get navWorkspaces => '工作区';

  @override
  String get navSessions => '会话';

  @override
  String get navMcpSkills => 'MCP 与技能';

  @override
  String get navSettings => '设置';

  @override
  String get commonCopy => '复制';

  @override
  String get commonCopiedToClipboard => '已复制到剪贴板。';

  @override
  String get commonExpand => '展开';

  @override
  String get commonCollapse => '折叠';

  @override
  String get statusRunning => '进行中';

  @override
  String get statusCompleted => '完成';

  @override
  String get statusFailed => '失败';

  @override
  String get statusDeclined => '已拒绝';

  @override
  String get statusWaiting => '等待';

  @override
  String get sessionComposerMentionLoading => '正在查找文件与提交...';

  @override
  String get sessionComposerMentionEmpty => '没有匹配的文件或提交。';

  @override
  String get sessionComposerMentionFile => '文件';

  @override
  String get sessionComposerMentionCommit => '提交';

  @override
  String get settingsPageTitle => '设置';

  @override
  String get settingsKicker => '偏好与连接';

  @override
  String get settingsRefreshModelsTooltip => '刷新模型列表';

  @override
  String get settingsStatusTitle => '设置状态';

  @override
  String settingsLoadFailed(String error) {
    return '读取设置失败：$error';
  }

  @override
  String get settingsSavingPreferences => '正在保存偏好...';

  @override
  String settingsActionFailed(String error) {
    return '执行失败：$error';
  }

  @override
  String get settingsSystemSection => '系统';

  @override
  String get settingsAppUpdates => '应用更新';

  @override
  String get settingsLanguageTitle => '应用语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageChineseSimplified => '简体中文';

  @override
  String get settingsLanguageUpdated => '已更新语言偏好。';

  @override
  String get settingsConnectionSection => '连接';

  @override
  String get settingsDefaultValue => '默认';

  @override
  String get settingsHide => '隐藏';

  @override
  String get settingsShow => '显示';

  @override
  String get settingsBaseUrlOptional => 'Base URL（可选）';

  @override
  String get settingsSave => '保存';

  @override
  String get settingsDefaultModel => '默认模型';

  @override
  String get settingsChooseModel => '选择模型';

  @override
  String get settingsModelsEmpty => '未返回可用模型列表。';

  @override
  String get settingsModelsRefreshed => '已刷新模型列表。';

  @override
  String settingsModelsFetchFailed(String error) {
    return '获取模型列表失败：$error';
  }

  @override
  String get settingsConnectionSaving => '正在保存连接设置...';

  @override
  String get settingsConnectionCleared => '已清除密钥和服务地址。';

  @override
  String get settingsConnectionBaseSavedKeyCleared => '已保存服务地址，并清除密钥。';

  @override
  String get settingsConnectionKeySavedBaseCleared => '已保存密钥，并清除服务地址。';

  @override
  String get settingsConnectionSaved => '已保存密钥和服务地址。';

  @override
  String settingsConnectionSavedModelsEmpty(String status) {
    return '$status 未返回可用模型列表。';
  }

  @override
  String settingsConnectionSavedModelsRefreshed(String status) {
    return '$status 已刷新模型列表。';
  }

  @override
  String settingsConnectionSavedModelsFetchFailed(String status, String error) {
    return '$status 获取模型列表失败：$error';
  }

  @override
  String settingsModelUpdated(String model) {
    return '已更新模型为：$model';
  }

  @override
  String get settingsAdvancedConfig => '高级配置';

  @override
  String get settingsEffectivePreview => '生效预览';

  @override
  String get settingsNoPreviewContent => '# 暂无可预览内容';

  @override
  String get settingsExtraConfig => '附加配置';

  @override
  String get settingsExtraConfigItems => '附加配置项';

  @override
  String get settingsExtraConfigHelp =>
      '附加配置会插入到自动生成的顶层键之后、各分组之前。不要在这里重复填写连接、模型、features 或 MCP 服务器。';

  @override
  String get settingsSaveContent => '保存内容';

  @override
  String get settingsClearContent => '清空内容';

  @override
  String settingsExtraConfigSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get settingsExtraConfigSaving => '正在保存补充配置...';

  @override
  String get settingsExtraConfigClearedRuntime => '已清空补充配置，当前仅使用自动生成内容。';

  @override
  String get settingsExtraConfigSaved => '已保存补充配置。';

  @override
  String get settingsExtraConfigAlreadyBlank => '补充配置已是空白。';

  @override
  String get settingsExtraConfigClearing => '正在清空补充配置...';

  @override
  String get settingsExtraConfigCleared => '已清空补充配置。';

  @override
  String get settingsInteractionPreferences => '交互偏好';

  @override
  String get settingsShowReasoning => '显示推理过程';

  @override
  String get settingsShowReasoningOn => '已开启思考内容展示。';

  @override
  String get settingsShowReasoningOff => '已关闭思考内容展示。';

  @override
  String get settingsRunLogs => '运行日志';

  @override
  String get settingsRunLogsOn => '已开启运行日志。';

  @override
  String get settingsRunLogsOff => '已关闭运行日志。';

  @override
  String settingsLogRetentionDays(int days) {
    return '日志保留天数：$days 天';
  }

  @override
  String get settingsLogRetentionUpdated => '已更新日志保留天数。';

  @override
  String get settingsSyncing => '正在同步设置';
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get appTitle => 'CodexM';

  @override
  String get navWorkspaces => '工作区';

  @override
  String get navSessions => '会话';

  @override
  String get navMcpSkills => 'MCP 与技能';

  @override
  String get navSettings => '设置';

  @override
  String get commonCopy => '复制';

  @override
  String get commonCopiedToClipboard => '已复制到剪贴板。';

  @override
  String get commonExpand => '展开';

  @override
  String get commonCollapse => '折叠';

  @override
  String get statusRunning => '进行中';

  @override
  String get statusCompleted => '完成';

  @override
  String get statusFailed => '失败';

  @override
  String get statusDeclined => '已拒绝';

  @override
  String get statusWaiting => '等待';

  @override
  String get sessionComposerMentionLoading => '正在查找文件与提交...';

  @override
  String get sessionComposerMentionEmpty => '没有匹配的文件或提交。';

  @override
  String get sessionComposerMentionFile => '文件';

  @override
  String get sessionComposerMentionCommit => '提交';

  @override
  String get settingsPageTitle => '设置';

  @override
  String get settingsKicker => '偏好与连接';

  @override
  String get settingsRefreshModelsTooltip => '刷新模型列表';

  @override
  String get settingsStatusTitle => '设置状态';

  @override
  String settingsLoadFailed(String error) {
    return '读取设置失败：$error';
  }

  @override
  String get settingsSavingPreferences => '正在保存偏好...';

  @override
  String settingsActionFailed(String error) {
    return '执行失败：$error';
  }

  @override
  String get settingsSystemSection => '系统';

  @override
  String get settingsAppUpdates => '应用更新';

  @override
  String get settingsLanguageTitle => '应用语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageChineseSimplified => '简体中文';

  @override
  String get settingsLanguageUpdated => '已更新语言偏好。';

  @override
  String get settingsConnectionSection => '连接';

  @override
  String get settingsDefaultValue => '默认';

  @override
  String get settingsHide => '隐藏';

  @override
  String get settingsShow => '显示';

  @override
  String get settingsBaseUrlOptional => 'Base URL（可选）';

  @override
  String get settingsSave => '保存';

  @override
  String get settingsDefaultModel => '默认模型';

  @override
  String get settingsChooseModel => '选择模型';

  @override
  String get settingsModelsEmpty => '未返回可用模型列表。';

  @override
  String get settingsModelsRefreshed => '已刷新模型列表。';

  @override
  String settingsModelsFetchFailed(String error) {
    return '获取模型列表失败：$error';
  }

  @override
  String get settingsConnectionSaving => '正在保存连接设置...';

  @override
  String get settingsConnectionCleared => '已清除密钥和服务地址。';

  @override
  String get settingsConnectionBaseSavedKeyCleared => '已保存服务地址，并清除密钥。';

  @override
  String get settingsConnectionKeySavedBaseCleared => '已保存密钥，并清除服务地址。';

  @override
  String get settingsConnectionSaved => '已保存密钥和服务地址。';

  @override
  String settingsConnectionSavedModelsEmpty(String status) {
    return '$status 未返回可用模型列表。';
  }

  @override
  String settingsConnectionSavedModelsRefreshed(String status) {
    return '$status 已刷新模型列表。';
  }

  @override
  String settingsConnectionSavedModelsFetchFailed(String status, String error) {
    return '$status 获取模型列表失败：$error';
  }

  @override
  String settingsModelUpdated(String model) {
    return '已更新模型为：$model';
  }

  @override
  String get settingsAdvancedConfig => '高级配置';

  @override
  String get settingsEffectivePreview => '生效预览';

  @override
  String get settingsNoPreviewContent => '# 暂无可预览内容';

  @override
  String get settingsExtraConfig => '附加配置';

  @override
  String get settingsExtraConfigItems => '附加配置项';

  @override
  String get settingsExtraConfigHelp =>
      '附加配置会插入到自动生成的顶层键之后、各分组之前。不要在这里重复填写连接、模型、features 或 MCP 服务器。';

  @override
  String get settingsSaveContent => '保存内容';

  @override
  String get settingsClearContent => '清空内容';

  @override
  String settingsExtraConfigSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get settingsExtraConfigSaving => '正在保存补充配置...';

  @override
  String get settingsExtraConfigClearedRuntime => '已清空补充配置，当前仅使用自动生成内容。';

  @override
  String get settingsExtraConfigSaved => '已保存补充配置。';

  @override
  String get settingsExtraConfigAlreadyBlank => '补充配置已是空白。';

  @override
  String get settingsExtraConfigClearing => '正在清空补充配置...';

  @override
  String get settingsExtraConfigCleared => '已清空补充配置。';

  @override
  String get settingsInteractionPreferences => '交互偏好';

  @override
  String get settingsShowReasoning => '显示推理过程';

  @override
  String get settingsShowReasoningOn => '已开启思考内容展示。';

  @override
  String get settingsShowReasoningOff => '已关闭思考内容展示。';

  @override
  String get settingsRunLogs => '运行日志';

  @override
  String get settingsRunLogsOn => '已开启运行日志。';

  @override
  String get settingsRunLogsOff => '已关闭运行日志。';

  @override
  String settingsLogRetentionDays(int days) {
    return '日志保留天数：$days 天';
  }

  @override
  String get settingsLogRetentionUpdated => '已更新日志保留天数。';

  @override
  String get settingsSyncing => '正在同步设置';
}
