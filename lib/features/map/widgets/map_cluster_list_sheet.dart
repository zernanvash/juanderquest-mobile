import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class MapClusterListItem {
  const MapClusterListItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

class MapClusterListSheet extends StatelessWidget {
  const MapClusterListSheet({
    required this.items,
    required this.onSelect,
    super.key,
  });

  final List<MapClusterListItem> items;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Destinations at this location',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close destination list',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text('${items.length} destinations', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: Icon(item.icon, color: AppColors.primary),
                      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => onSelect(item.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
