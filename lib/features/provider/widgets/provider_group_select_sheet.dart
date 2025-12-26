import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../icons/lucide_adapter.dart';

/// 为供应商选择分组的弹窗
Future<String?> showProviderGroupSelectSheet(
  BuildContext context,
  String providerKey,
) async {
  return await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _ProviderGroupSelectSheet(providerKey: providerKey),
  );
}

class _ProviderGroupSelectSheet extends StatelessWidget {
  const _ProviderGroupSelectSheet({required this.providerKey});

  final String providerKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final groups = settings.providerGroups;

    // 查找当前供应商所在的分组
    String? currentGroupId;
    for (final g in groups) {
      if (g.providerKeys.contains(providerKey)) {
        currentGroupId = g.id;
        break;
      }
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
            // 标题
            Text(
              l10n.providerGroupMoveToGroup,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            // 分组列表
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final isDefault = group.id == ProviderGroup.defaultGroupId;
                  final isCurrent = group.id == currentGroupId;

                  return ListTile(
                    leading: Icon(
                      Lucide.Folder,
                      color: isCurrent
                          ? cs.primary
                          : cs.onSurface.withOpacity(0.7),
                    ),
                    title: Text(
                      isDefault ? l10n.providerGroupDefaultName : group.name,
                      style: TextStyle(
                        fontWeight: isCurrent
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isCurrent ? cs.primary : null,
                      ),
                    ),
                    trailing: isCurrent
                        ? Icon(Lucide.Check, size: 20, color: cs.primary)
                        : null,
                    onTap: isCurrent
                        ? null
                        : () async {
                            await context
                                .read<SettingsProvider>()
                                .moveProviderToGroup(providerKey, group.id);
                            if (context.mounted) {
                              Navigator.of(context).pop(group.id);
                            }
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
