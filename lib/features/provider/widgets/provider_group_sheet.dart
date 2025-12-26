import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';

/// 分组管理弹窗
Future<void> showProviderGroupSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => const _ProviderGroupSheet(),
  );
}

class _ProviderGroupSheet extends StatefulWidget {
  const _ProviderGroupSheet();

  @override
  State<_ProviderGroupSheet> createState() => _ProviderGroupSheetState();
}

class _ProviderGroupSheetState extends State<_ProviderGroupSheet> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final groups = settings.providerGroups;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽条
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 标题行
            Row(
              children: [
                Text(
                  l10n.providerGroupManageTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // 添加分组按钮
                IconButton(
                  icon: Icon(Lucide.Plus, size: 20, color: cs.primary),
                  onPressed: () => _showAddGroupDialog(context),
                  tooltip: l10n.providerGroupAddTitle,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 分组列表
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    l10n.providerGroupEmptyHint,
                    style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  itemCount: groups.length,
                  onReorder: (oldIndex, newIndex) async {
                    await settings.reorderGroups(oldIndex, newIndex);
                  },
                  proxyDecorator: (child, index, animation) => Material(
                    color: Colors.transparent,
                    elevation: 2,
                    child: child,
                  ),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final isDefault = group.id == ProviderGroup.defaultGroupId;
                    final providerCount = group.providerKeys.length;

                    return ListTile(
                      key: ValueKey(group.id),
                      leading: Icon(
                        Lucide.Folder,
                        color: isDefault
                            ? cs.primary
                            : cs.onSurface.withOpacity(0.7),
                      ),
                      title: Text(
                        isDefault ? l10n.providerGroupDefaultName : group.name,
                        style: TextStyle(
                          fontWeight: isDefault
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        l10n.providerGroupProvidersCount(providerCount),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.5),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isDefault) ...[
                            // 编辑按钮
                            IconButton(
                              icon: Icon(
                                Lucide.Pencil,
                                size: 18,
                                color: cs.onSurface.withOpacity(0.6),
                              ),
                              onPressed: () =>
                                  _showEditGroupDialog(context, group),
                              tooltip: l10n.providerGroupEditTitle,
                            ),
                            // 删除按钮
                            IconButton(
                              icon: const Icon(
                                Lucide.Trash2,
                                size: 18,
                                color: Colors.red,
                              ),
                              onPressed: () =>
                                  _showDeleteConfirm(context, group),
                              tooltip: l10n.providerGroupDeleteTitle,
                            ),
                          ],
                          ReorderableDragStartListener(
                            index: index,
                            child: Icon(
                              Lucide.GripVertical,
                              size: 20,
                              color: cs.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                      onTap: isDefault
                          ? null
                          : () => _showEditGroupDialog(context, group),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddGroupDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.providerGroupAddTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.providerGroupNameLabel,
            hintText: l10n.providerGroupNameHint,
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      await context.read<SettingsProvider>().addProviderGroup(result);
      if (mounted) {
        showAppSnackBar(
          context,
          message: l10n.providerGroupAddedSnackbar,
          type: NotificationType.success,
        );
      }
    }
  }

  Future<void> _showEditGroupDialog(
    BuildContext context,
    ProviderGroup group,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: group.name);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.providerGroupEditTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.providerGroupNameLabel,
            hintText: l10n.providerGroupNameHint,
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );

    if (result != null &&
        result.isNotEmpty &&
        result != group.name &&
        mounted) {
      await context.read<SettingsProvider>().updateProviderGroup(
        group.copyWith(name: result),
      );
      if (mounted) {
        showAppSnackBar(
          context,
          message: l10n.providerGroupUpdatedSnackbar,
          type: NotificationType.success,
        );
      }
    }
  }

  Future<void> _showDeleteConfirm(
    BuildContext context,
    ProviderGroup group,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.providerGroupDeleteTitle),
        content: Text(l10n.providerGroupDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              MaterialLocalizations.of(ctx).deleteButtonTooltip,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<SettingsProvider>().removeProviderGroup(group.id);
      if (mounted) {
        showAppSnackBar(
          context,
          message: l10n.providerGroupDeletedSnackbar,
          type: NotificationType.success,
        );
      }
    }
  }
}
