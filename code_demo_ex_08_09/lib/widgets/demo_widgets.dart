import 'package:flutter/material.dart';

String formatBytes(int bytes) => bytes < 1024
    ? '$bytes B'
    : bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KiB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MiB';

String formatDuration(int microseconds) =>
    '${(microseconds / 1000).toStringAsFixed(1)} ms';

class DemoSection extends StatelessWidget {
  const DemoSection({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

class FlowExplanation extends StatelessWidget {
  const FlowExplanation({super.key, required this.steps});
  final List<String> steps;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (var i = 0; i < steps.length; i++) ...[
        if (i > 0) const Icon(Icons.arrow_forward, size: 18),
        Chip(label: Text(steps[i])),
      ],
    ],
  );
}

class CodeExample extends StatelessWidget {
  const CodeExample({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: const Text('Xem code chính yếu'),
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: const Color(0xFF10273C),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText(
            code,
            style: const TextStyle(
              color: Color(0xFFECF4FA),
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ),
    ],
  );
}

class ErrorMessage extends StatelessWidget {
  const ErrorMessage(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}
