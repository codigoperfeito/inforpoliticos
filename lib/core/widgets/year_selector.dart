import 'package:flutter/material.dart';

class YearSelector extends StatelessWidget {
  const YearSelector({
    super.key,
    required this.years,
    required this.selectedYear,
    required this.onSelected,
  });

  final List<int> years;
  final int selectedYear;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: years.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final year = years[index];
          final active = year == selectedYear;
          return ChoiceChip(
            label: Text('$year'),
            selected: active,
            onSelected: (_) => onSelected(year),
          );
        },
      ),
    );
  }
}
