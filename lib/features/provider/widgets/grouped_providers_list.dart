import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../pages/provider_detail_page.dart';
import 'provider_group_select_sheet.dart';
import 'provider_avatar.dart';
import '../../../shared/widgets/ios_checkbox.dart';

/// 内置供应商 key 列表（与 providers_page.dart 中的顺序一致）
List<String> getBuiltinProviderKeys() {
  return [
    'OpenAI',
    'SiliconFlow',
    'Gemini',
    'OpenRouter',
    'KelivoIN',
    'Tensdaq',
    'DeepSeek',
    'AIhubmix',
    'Aliyun',
    'Zhipu AI',
    'Claude',
    'Grok',
    'ByteDance',
  ];
}

/// 带分组的供应商列表组件
class GroupedProvidersList extends StatelessWidget {
  const GroupedProvidersList({
    super.key,
    required this.selectMode,
    required this.selectedKeys,
    required this.onToggleSelect,
  });

  final bool selectMode;
  final Set<String> selectedKeys;
  final void Function(String key) onToggleSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    final borderColor = cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06);
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();

    // 获取所有供应商 key（内置 + 动态）
    final builtinKeys = getBuiltinProviderKeys();
    final dynamicKeys = settings.providerConfigs.keys
        .where((k) => !builtinKeys.contains(k))
        .toList();
    final allProviderKeys = <String>{...builtinKeys, ...dynamicKeys};

    // 获取分组并确保每个分组中的供应商都存在
    var groups = settings.providerGroups;

    // 检查是否需要刷新分组（首次加载时可能分组为空）
    if (groups.isEmpty) {
      // 创建临时默认分组用于显示
      groups = [
        ProviderGroup.createDefault(providerKeys: allProviderKeys.toList()),
      ];
    } else {
      // 检查是否有供应商不在任何分组中（新增的内置或动态供应商）
      final assignedKeys = <String>{};
      for (final g in groups) {
        assignedKeys.addAll(g.providerKeys);
      }
      final unassignedKeys = allProviderKeys.difference(assignedKeys);

      if (unassignedKeys.isNotEmpty) {
        // 将未分配的供应商添加到默认分组
        final defaultGroupIndex = groups.indexWhere(
          (g) => g.id == ProviderGroup.defaultGroupId,
        );
        if (defaultGroupIndex >= 0) {
          // 异步更新，但当前显示时包含这些键
          final updatedDefault = groups[defaultGroupIndex].copyWith(
            providerKeys: [
              ...groups[defaultGroupIndex].providerKeys,
              ...unassignedKeys,
            ],
          );
          groups = List.from(groups)..[defaultGroupIndex] = updatedDefault;
          // 触发异步保存
          Future.microtask(() async {
            for (final k in unassignedKeys) {
              await settings.ensureProviderInGroup(k);
            }
          });
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: groups.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l10n.providerGroupEmptyHint,
                    style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: groups.length,
                itemBuilder: (context, groupIndex) {
                  final group = groups[groupIndex];
                  final isDefault = group.id == ProviderGroup.defaultGroupId;

                  return _GroupSection(
                    group: group,
                    isDefault: isDefault,
                    selectMode: selectMode,
                    selectedKeys: selectedKeys,
                    onToggleSelect: onToggleSelect,
                    onReorder: (oldIndex, newIndex) async {
                      await settings.reorderProvidersInGroup(
                        group.id,
                        oldIndex,
                        newIndex,
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

/// 单个分组区块
class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.group,
    required this.isDefault,
    required this.selectMode,
    required this.selectedKeys,
    required this.onToggleSelect,
    required this.onReorder,
  });

  final ProviderGroup group;
  final bool isDefault;
  final bool selectMode;
  final Set<String> selectedKeys;
  final void Function(String key) onToggleSelect;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();

    // 将启用的供应商排在最上面
    final providerKeys = List<String>.from(group.providerKeys);
    providerKeys.sort((a, b) {
      final aEnabled = settings.getProviderConfig(a).enabled;
      final bEnabled = settings.getProviderConfig(b).enabled;
      if (aEnabled == bEnabled) return 0;
      return aEnabled ? -1 : 1; // 启用的排在前面
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分组头部
        _GroupHeader(
          group: group,
          isDefault: isDefault,
          onToggleCollapsed: () => settings.toggleGroupCollapsed(group.id),
          onToggleEnabled: () => settings.toggleGroupEnabled(group.id),
        ),
        // 折叠动画
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: group.collapsed
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: const SizedBox.shrink(),
          secondChild: providerKeys.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Text(
                    l10n.providerGroupEmptyHint,
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < providerKeys.length; i++) ...[
                      _ProviderRow(
                        providerKey: providerKeys[i],
                        groupId: group.id,
                        selectMode: selectMode,
                        selected: selectedKeys.contains(providerKeys[i]),
                        onToggleSelect: onToggleSelect,
                        index: i,
                      ),
                      if (i < providerKeys.length - 1)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 56,
                          endIndent: 12,
                          color: cs.outlineVariant.withOpacity(0.12),
                        ),
                    ],
                  ],
                ),
        ),
        // 分组分隔线
        if (!group.collapsed)
          Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outlineVariant.withOpacity(0.15),
          ),
      ],
    );
  }
}

/// 分组头部
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.group,
    required this.isDefault,
    required this.onToggleCollapsed,
    required this.onToggleEnabled,
  });

  final ProviderGroup group;
  final bool isDefault;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onToggleEnabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return InkWell(
      onTap: onToggleCollapsed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // 折叠图标
            AnimatedRotation(
              turns: group.collapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Lucide.ChevronDown,
                size: 18,
                color: cs.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(width: 8),
            // 分组图标
            Icon(
              Lucide.Folder,
              size: 18,
              color: isDefault ? cs.primary : cs.onSurface.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            // 分组名称
            Expanded(
              child: Text(
                isDefault ? l10n.providerGroupDefaultName : group.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDefault ? cs.primary : cs.onSurface,
                ),
              ),
            ),
            // 供应商数量
            Text(
              l10n.providerGroupProvidersCount(group.providerKeys.length),
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withOpacity(0.4),
              ),
            ),
            const SizedBox(width: 8),
            // 启用/禁用开关
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: group.enabled,
                onChanged: (_) => onToggleEnabled(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单行供应商
class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.providerKey,
    required this.groupId,
    required this.selectMode,
    required this.selected,
    required this.onToggleSelect,
    required this.index,
  });

  final String providerKey;
  final String groupId;
  final bool selectMode;
  final bool selected;
  final void Function(String key) onToggleSelect;
  final int index;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final cfg = settings.getProviderConfig(providerKey);
    final enabled = cfg.enabled;

    final statusBg = enabled
        ? Colors.green.withOpacity(0.12)
        : Colors.orange.withOpacity(0.15);
    final statusFg = enabled ? Colors.green : Colors.orange;

    return InkWell(
      onTap: () {
        if (selectMode) {
          Haptics.light();
          onToggleSelect(providerKey);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProviderDetailPage(
                keyName: providerKey,
                displayName: cfg.name.isNotEmpty ? cfg.name : providerKey,
              ),
            ),
          );
        }
      },
      onLongPress: selectMode
          ? null
          : () => _showProviderContextMenu(context, providerKey, groupId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // 供应商头像
            ProviderAvatar(
              providerKey: providerKey,
              displayName: cfg.name.isNotEmpty ? cfg.name : providerKey,
              size: 32,
            ),
            const SizedBox(width: 12),
            // 供应商名称
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cfg.name.isNotEmpty ? cfg.name : providerKey,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withOpacity(enabled ? 1.0 : 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // 状态标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          enabled
                              ? l10n.providersPageEnabledStatus
                              : l10n.providersPageDisabledStatus,
                          style: TextStyle(
                            color: statusFg,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 模型数量
                      Text(
                        '${cfg.models.length} ${l10n.providersPageModelsCountSingleSuffix}',
                        style: TextStyle(
                          color: cs.onSurface.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 选择模式下的复选框
            if (selectMode)
              IosCheckbox(
                value: selected,
                onChanged: (_) => onToggleSelect(providerKey),
              )
            else
              Icon(
                Lucide.ChevronRight,
                size: 16,
                color: cs.onSurface.withOpacity(0.3),
              ),
          ],
        ),
      ),
    );
  }

  void _showProviderContextMenu(
    BuildContext context,
    String providerKey,
    String groupId,
  ) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽条
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 移动到分组
            ListTile(
              leading: const Icon(Lucide.Import),
              title: Text(l10n.providerGroupMoveToGroup),
              onTap: () async {
                Navigator.of(ctx).pop();
                await showProviderGroupSelectSheet(context, providerKey);
              },
            ),
          ],
        ),
      ),
    );
  }
}
