// Web版（CanvasKit）のRawChipにおける日本語フォント遅延読み込み時のテキスト幅計算ズレ（文字切れ）を回避する安全チップ群
import 'package:flutter/material.dart';

/// 選択式チップ（ChoiceChip互換）
class SafeChoiceChip extends StatelessWidget {
  final Widget? avatar;
  final Widget label;
  final bool selected;
  final Color? selectedColor;
  final Color? backgroundColor;
  final BorderSide? side;
  final VisualDensity? visualDensity;
  final ValueChanged<bool>? onSelected;
  final bool showCheckmark;

  const SafeChoiceChip({
    super.key,
    this.avatar,
    required this.label,
    required this.selected,
    this.selectedColor,
    this.backgroundColor,
    this.side,
    this.visualDensity,
    required this.onSelected,
    this.showCheckmark = true,
  });

  @override
  Widget build(BuildContext context) {
    return _SafeBaseChip(
      avatar: avatar,
      label: label,
      selected: selected,
      selectedColor: selectedColor,
      backgroundColor: backgroundColor,
      side: side,
      visualDensity: visualDensity,
      showCheckmark: showCheckmark,
      onTap: onSelected == null ? null : () => onSelected!(!selected),
    );
  }
}

/// フィルター式チップ（FilterChip互換）
class SafeFilterChip extends StatelessWidget {
  final Widget? avatar;
  final Widget label;
  final bool selected;
  final Color? selectedColor;
  final Color? backgroundColor;
  final BorderSide? side;
  final VisualDensity? visualDensity;
  final ValueChanged<bool>? onSelected;
  final bool showCheckmark;

  const SafeFilterChip({
    super.key,
    this.avatar,
    required this.label,
    required this.selected,
    this.selectedColor,
    this.backgroundColor,
    this.side,
    this.visualDensity,
    required this.onSelected,
    this.showCheckmark = true,
  });

  @override
  Widget build(BuildContext context) {
    return _SafeBaseChip(
      avatar: avatar,
      label: label,
      selected: selected,
      selectedColor: selectedColor,
      backgroundColor: backgroundColor,
      side: side,
      visualDensity: visualDensity,
      showCheckmark: showCheckmark,
      onTap: onSelected == null ? null : () => onSelected!(!selected),
    );
  }
}

/// アクションチップ（ActionChip互換）
class SafeActionChip extends StatelessWidget {
  final Widget? avatar;
  final Widget label;
  final Color? backgroundColor;
  final BorderSide? side;
  final VisualDensity? visualDensity;
  final VoidCallback? onPressed;

  const SafeActionChip({
    super.key,
    this.avatar,
    required this.label,
    this.backgroundColor,
    this.side,
    this.visualDensity,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _SafeBaseChip(
      avatar: avatar,
      label: label,
      selected: false,
      backgroundColor: backgroundColor,
      side: side,
      visualDensity: visualDensity,
      showCheckmark: false,
      onTap: onPressed,
    );
  }
}

/// 表示専用チップ（Chip互換）
class SafeChip extends StatelessWidget {
  final Widget? avatar;
  final Widget label;
  final Color? backgroundColor;
  final BorderSide? side;
  final VisualDensity? visualDensity;

  const SafeChip({
    super.key,
    this.avatar,
    required this.label,
    this.backgroundColor,
    this.side,
    this.visualDensity,
  });

  @override
  Widget build(BuildContext context) {
    return _SafeBaseChip(
      avatar: avatar,
      label: label,
      selected: false,
      backgroundColor: backgroundColor,
      side: side,
      visualDensity: visualDensity,
      showCheckmark: false,
      onTap: null,
      isStaticChip: true,
    );
  }
}

/// 全チップ共通の内部実装（RawChipを使わずRow直接レイアウト＋systemFonts監視でWebの文字切れを防止）
class _SafeBaseChip extends StatefulWidget {
  final Widget? avatar;
  final Widget label;
  final bool selected;
  final Color? selectedColor;
  final Color? backgroundColor;
  final BorderSide? side;
  final VisualDensity? visualDensity;
  final bool showCheckmark;
  final VoidCallback? onTap;
  final bool isStaticChip;

  const _SafeBaseChip({
    this.avatar,
    required this.label,
    required this.selected,
    this.selectedColor,
    this.backgroundColor,
    this.side,
    this.visualDensity,
    required this.showCheckmark,
    this.onTap,
    this.isStaticChip = false,
  });

  @override
  State<_SafeBaseChip> createState() => _SafeBaseChipState();
}

class _SafeBaseChipState extends State<_SafeBaseChip> {
  int _fontEpoch = 0;

  @override
  void initState() {
    super.initState();
    // Web版で日本語フォールバックフォントの非同期ロードが完了した際にレイアウトを確実に再計測する
    PaintingBinding.instance.systemFonts.addListener(_handleSystemFontsChanged);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts
        .removeListener(_handleSystemFontsChanged);
    super.dispose();
  }

  void _handleSystemFontsChanged() {
    if (!mounted) return;
    setState(() {
      _fontEpoch++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompact = widget.visualDensity == VisualDensity.compact;
    final isDisabled = !widget.isStaticChip && widget.onTap == null;

    final Color bgColor;
    if (widget.selected) {
      bgColor = widget.selectedColor ?? colorScheme.secondaryContainer;
    } else if (widget.backgroundColor != null) {
      bgColor = widget.backgroundColor!;
    } else {
      bgColor = colorScheme.surface;
    }

    final BorderSide resolvedSide = widget.side ??
        BorderSide(
          color: widget.selected
              ? Colors.transparent
              : colorScheme.outlineVariant,
          width: 1.0,
        );

    final Color fgColor = isDisabled
        ? colorScheme.onSurface.withValues(alpha: 0.38)
        : (widget.selected
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurfaceVariant);

    final baseLabelStyle = (theme.textTheme.labelLarge ??
            const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500))
        .copyWith(
      color: fgColor,
      locale: const Locale('ja', 'JP'),
    );

    final Widget? leading;
    if (widget.avatar != null) {
      leading = widget.avatar;
    } else if (widget.selected && widget.showCheckmark) {
      leading = Icon(Icons.check, size: isCompact ? 15 : 17, color: fgColor);
    } else {
      leading = null;
    }

    final horizontalPad = isCompact ? 9.0 : 12.0;
    final verticalPad = isCompact ? 4.5 : 6.5;

    final Widget content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPad,
        vertical: verticalPad,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            IconTheme.merge(
              data: IconThemeData(size: isCompact ? 16 : 18, color: fgColor),
              child: DefaultTextStyle.merge(
                style: TextStyle(fontSize: isCompact ? 13 : 14),
                child: leading,
              ),
            ),
            const SizedBox(width: 5),
          ],
          KeyedSubtree(
            key: ValueKey(_fontEpoch),
            child: DefaultTextStyle(
              style: baseLabelStyle,
              softWrap: false,
              maxLines: 1,
              overflow: TextOverflow.visible,
              child: widget.label,
            ),
          ),
        ],
      ),
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: resolvedSide,
    );

    return Semantics(
      button: !widget.isStaticChip,
      selected: widget.selected,
      enabled: !isDisabled,
      child: Material(
        color: bgColor,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: widget.onTap != null
            ? InkWell(
                onTap: widget.onTap,
                customBorder: shape,
                child: content,
              )
            : content,
      ),
    );
  }
}
