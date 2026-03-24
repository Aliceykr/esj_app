import 'package:flutter/material.dart';

class CategoryBar extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String>? onSelected;

  const CategoryBar({
    super.key,
    required this.categories,
    this.selected,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat == selected;
          return FilterChip(
            label: Text(cat, style: const TextStyle(fontSize: 12)),
            selected: isSelected,
            onSelected: (_) => onSelected?.call(cat),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}
