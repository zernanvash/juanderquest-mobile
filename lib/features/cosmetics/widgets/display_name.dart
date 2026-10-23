import 'package:flutter/material.dart';

class DisplayName extends StatelessWidget {
  const DisplayName(
      {super.key, required this.name, this.title, this.color, this.style});
  final String name;
  final String? title;
  final Color? color;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(name,
                style: (style ?? const TextStyle(fontWeight: FontWeight.bold))
                    .copyWith(color: color ?? style?.color)),
            if (title != null && title!.isNotEmpty)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(title!,
                      style: TextStyle(
                          color: Colors.brown.shade800,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)))
          ]);
}
