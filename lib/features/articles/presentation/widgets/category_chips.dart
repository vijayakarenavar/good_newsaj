import 'package:flutter/material.dart';

/// Widget for displaying category filter chips with auto-scroll support
class CategoryChips extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final int? selectedCategoryId;
  final Function(int?) onCategorySelected;
  final ScrollController? scrollController;
  final int? activeCategoryIndex;

  const CategoryChips({
    Key? key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    this.scrollController,
    this.activeCategoryIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = activeCategoryIndex != null
              ? index == activeCategoryIndex
              : selectedCategoryId == category['id'];

          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => onCategorySelected(category['id'] as int?),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    category['name'] as String,
                    style: TextStyle(
                      color: isSelected
                          ? colorScheme.primary
                          : isDark ? Colors.white60 : Colors.grey[600],
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: isSelected ? 15 : 13,
                    ),
                  ),
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        height: 2.5,
                        width: 30,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}