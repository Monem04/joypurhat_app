import 'package:flutter/material.dart';

import '../services/launcher.dart';
import '../theme.dart';
import '../utils/bn.dart';

/// White rounded card used for every section.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Material (not a coloured Container) so ListTile and InkWell ripples
    // inside a panel stay visible.
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x0D10201F), blurRadius: 2, offset: Offset(0, 1)),
            BoxShadow(color: Color(0x0F10201F), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Material(
          color: color ?? AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class IconBox extends StatelessWidget {
  const IconBox(this.icon, {super.key, this.size = 46, this.bg = AppColors.tint, this.fg = AppColors.primary});
  final IconData icon;
  final double size;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, color: fg, size: size * 0.52),
    );
  }
}

/// Small rounded label.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.bg = AppColors.tint, this.fg = AppColors.primaryDark, this.icon});
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(text,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// "নমুনা" for invented sample entries shown in demo mode.
class SampleBadge extends StatelessWidget {
  const SampleBadge({super.key});

  @override
  Widget build(BuildContext context) =>
      const Pill('নমুনা', bg: AppColors.warnBg, fg: AppColors.warnText, icon: Icons.science_outlined);
}

/// Shown when the only source is old or a single directory.
class CheckBadge extends StatelessWidget {
  const CheckBadge({super.key});

  @override
  Widget build(BuildContext context) =>
      const Pill('যাচাই করে নিন', bg: AppColors.warnBg, fg: AppColors.warnText, icon: Icons.help_outline);
}

class NoteBanner extends StatelessWidget {
  const NoteBanner(this.text, {super.key, this.icon = Icons.info_outline, this.bg = AppColors.surface, this.fg = AppColors.textSoft});
  final String text;
  final IconData icon;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, height: 1.45, color: fg))),
        ],
      ),
    );
  }
}

class DemoBanner extends StatelessWidget {
  const DemoBanner(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => NoteBanner(
        text,
        icon: Icons.science_outlined,
        bg: AppColors.warnBg,
        fg: AppColors.warnText,
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        children: [
          IconBox(icon, size: 56),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.muted)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// One labelled line with an icon: address, time, phone, price.
class InfoLine extends StatelessWidget {
  const InfoLine({super.key, required this.icon, required this.label, required this.value, this.onTap, this.divider = true});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: divider ? const Border(bottom: BorderSide(color: AppColors.divider)) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class ChipsWrap extends StatelessWidget {
  const ChipsWrap(this.chips, {super.key});
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(c, style: const TextStyle(fontSize: 13.5, color: AppColors.textSoft)),
          ),
      ],
    );
  }
}

/// Horizontal filter chips.
class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.filters, required this.selected, required this.onSelected});
  final List<String> filters;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final on = i == selected;
          return ChoiceChip(
            label: Text(filters[i]),
            selected: on,
            showCheckmark: false,
            labelStyle: TextStyle(
              color: on ? Colors.white : AppColors.text,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            side: BorderSide(color: on ? AppColors.primary : AppColors.border),
            onSelected: (_) => onSelected(i),
          );
        },
      ),
    );
  }
}

/// Calls one number, or asks which one when there are several.
Future<void> callNumbers(BuildContext context, String name, List<String> numbers) async {
  if (numbers.isEmpty) return;
  if (numbers.length == 1) return Launch.call(context, numbers.first);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('কোন নম্বরে কল করবেন?', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 8),
            for (final n in numbers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const IconBox(Icons.call_outlined, size: 40),
                title: Text(phoneBn(n), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  Launch.call(context, n);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

/// Round call button used in lists.
class CallButton extends StatelessWidget {
  const CallButton({super.key, required this.name, required this.numbers, this.size = 46});
  final String name;
  final List<String> numbers;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$name, কল করুন',
      child: Material(
        color: AppColors.success,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => callNumbers(context, name, numbers),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(Icons.call, color: Colors.white, size: size * 0.48),
          ),
        ),
      ),
    );
  }
}

/// Source links and the date the data was checked.
class SourcesPanel extends StatelessWidget {
  const SourcesPanel({super.key, required this.sources, this.checked = '', this.note = ''});
  final List<String> sources;
  final String checked;
  final String note;

  static String host(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.host.isEmpty) return url;
    return u.host.replaceFirst('www.', '');
  }

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty && note.isEmpty) return const SizedBox.shrink();
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.verified_outlined, color: AppColors.accent),
          title: const Text('তথ্যের উৎস', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: checked.isEmpty
              ? null
              : Text('শেষ যাচাই: ${fullDateBn(DateTime.parse(checked))}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(note, style: const TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.textSoft)),
              ),
            for (final s in sources)
              s.startsWith('http')
                  ? InkWell(
                      onTap: () => Launch.web(context, s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.link, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(host(s),
                                  style: const TextStyle(
                                      color: AppColors.primary, decoration: TextDecoration.underline)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(s, style: const TextStyle(color: AppColors.textSoft)),
                    ),
          ],
        ),
      ),
    );
  }
}

/// A big full-width action at the bottom of a screen.
class BottomAction extends StatelessWidget {
  const BottomAction({super.key, required this.label, required this.onPressed, this.leading, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (leading != null) ...[Expanded(child: leading!), const SizedBox(width: 12)],
              Expanded(
                flex: leading == null ? 1 : 1,
                child: FilledButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon ?? Icons.arrow_forward),
                  label: Text(label, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showToast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
