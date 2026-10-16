import 'package:flutter/material.dart';

/// লেখা যায় এবং সিড করা পরামর্শও দেখায় - জেলা ও এলাকার জন্য।
class SuggestField extends StatelessWidget {
  const SuggestField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.optionsBuilder,
    required this.onChanged,
    this.validator,
    this.maxLength,
  });

  final String label;
  final String initialValue;
  final List<String> Function() optionsBuilder;
  final ValueChanged<String> onChanged;
  final String? Function(String?)? validator;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: initialValue),
      optionsBuilder: (value) {
        final query = value.text.trim();
        final all = optionsBuilder();
        return query.isEmpty
            ? all
            : all.where((option) => option.toLowerCase().contains(query.toLowerCase()));
      },
      onSelected: onChanged,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          maxLength: maxLength,
          decoration: InputDecoration(labelText: label),
          onChanged: onChanged,
          validator: validator,
        );
      },
    );
  }
}
