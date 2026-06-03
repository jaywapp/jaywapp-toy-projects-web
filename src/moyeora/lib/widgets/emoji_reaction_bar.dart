import 'package:flutter/material.dart';

class EmojiReactionBar extends StatefulWidget {
  const EmojiReactionBar({
    super.key,
    required this.reactionCounts,
    required this.myEmoji,
    this.onToggle,
    this.emojis = const ['👍', '👏', '❤️', '🙏', '😂'],
  });

  final Map<String, int> reactionCounts;
  final String? myEmoji;
  final ValueChanged<String>? onToggle;
  final List<String> emojis;

  @override
  State<EmojiReactionBar> createState() => _EmojiReactionBarState();
}

class _EmojiReactionBarState extends State<EmojiReactionBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeEmojis = widget.emojis
        .where((e) => (widget.reactionCounts[e] ?? 0) > 0)
        .toList();

    final displayEmojis = _expanded ? widget.emojis : activeEmojis;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final emoji in displayEmojis)
          _buildEmojiChip(
            emoji: emoji,
            count: widget.reactionCounts[emoji] ?? 0,
            selected: widget.myEmoji == emoji,
            colorScheme: colorScheme,
          ),
        _buildAddButton(colorScheme),
      ],
    );
  }

  Widget _buildEmojiChip({
    required String emoji,
    required int count,
    required bool selected,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: widget.onToggle != null ? () => widget.onToggle!(emoji) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.3)
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          count > 0 ? '$emoji $count' : emoji,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(ColorScheme colorScheme) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Icon(
          _expanded ? Icons.close : Icons.add_reaction_outlined,
          size: 14,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
