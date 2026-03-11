import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../app/theme/app_theme.dart';
import 'stitch_ui.dart';

@Preview(group: 'Stitch', name: 'Pills', size: Size(520, 220))
Widget stitchPillsPreview() {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              StitchPill(
                icon: Icons.vpn_key_outlined,
                label: '发送前需完成连接设置',
              ),
              StitchPill(
                icon: Icons.check_circle_outline,
                label: '可直接发送消息',
                emphasized: true,
              ),
              StitchPill(
                icon: Icons.chat_bubble_outline,
                label: '3 个会话',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

@Preview(group: 'Stitch', name: 'List items', size: Size(620, 360))
Widget stitchListItemsPreview() {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StitchListItem(
                title: '连接设置',
                subtitle: '配置 API Key 与模型后即可发送消息',
                leading: const Icon(Icons.settings_outlined),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const SizedBox(height: 12),
              StitchListItem(
                title: '工作区',
                subtitle: '从 Git 或本地目录创建/选择工作区',
                leading: const Icon(Icons.folder_outlined),
                trailing: const Icon(Icons.chevron_right),
                highlighted: true,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

@Preview(group: 'Stitch', name: 'Info banner', size: Size(620, 220))
Widget stitchInfoBannerPreview() {
  return MaterialApp(
    theme: buildAppTheme(),
    home: const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: StitchInfoBanner(
            icon: Icons.info_outline,
            title: '迁移进度提示',
            subtitle: '先创建一个工作区，然后在会话中开始迁移与验证。',
          ),
        ),
      ),
    ),
  );
}

@Preview(group: 'Stitch', name: 'Page scaffold', size: Size(1100, 900))
Widget stitchPageScaffoldPreview() {
  return MaterialApp(
    theme: buildAppTheme(),
    home: StitchPageScaffold(
      pageTitle: '示例页面',
      kickerText: 'WIDGET PREVIEW',
      topActions: const [
        IconButton(
          onPressed: null,
          icon: Icon(Icons.search_outlined),
          tooltip: 'Search',
        ),
        IconButton(
          onPressed: null,
          icon: Icon(Icons.more_horiz),
          tooltip: 'More',
        ),
      ],
      children: [
        const StitchSectionHeader(title: '状态'),
        const StitchInfoBanner(
          icon: Icons.check_circle_outline,
          title: '已就绪',
          subtitle: '组件可在 Widget Previewer 中独立渲染。',
        ),
        const StitchSectionHeader(title: '列表'),
        StitchListItem(
          title: '开始',
          subtitle: '从这里进入主要流程',
          leading: const Icon(Icons.play_arrow),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
      ],
    ),
  );
}

