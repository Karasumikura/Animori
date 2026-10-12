import 'package:flutter/material.dart';
import 'package:animori/bean/widget/animori_design.dart';

class AnimoriNavigation extends StatelessWidget {
  const AnimoriNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSearch,
    this.vertical = false,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onSearch;
  final bool vertical;

  static const labels = ['发现', '放送', '资料库', '我的空间'];
  static const icons = [
    Icons.explore_outlined,
    Icons.calendar_month_outlined,
    Icons.bookmarks_outlined,
    Icons.person_outline_rounded,
  ];

  Widget _destination(BuildContext context, int index) {
    final colors = Theme.of(context).colorScheme;
    final selected = index == selectedIndex;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? colors.primaryContainer.withValues(alpha: 0.72)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onSelect(index),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: vertical ? 18 : 4,
              vertical: 13,
            ),
            child: vertical
                ? Row(
                    children: [
                      Icon(
                        icons[index],
                        color: selected
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 14),
                      Flexible(child: Text(labels[index])),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icons[index],
                        size: 23,
                        color: selected
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        labels[index],
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimoriPanel(
    padding: EdgeInsets.all(vertical ? 16 : 6),
    child: vertical
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 20, 10, 4),
                child: Text(
                  'Animori',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 30),
                child: Text(
                  '每一帧，都值得。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded, size: 20),
                label: const Text('搜索番剧'),
              ),
              const SizedBox(height: 26),
              for (var i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _destination(context, i),
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  '画质优先\n自动比较来源与码率',
                  style: TextStyle(
                    height: 1.8,
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          )
        : Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(child: _destination(context, i)),
            ],
          ),
  );
}
