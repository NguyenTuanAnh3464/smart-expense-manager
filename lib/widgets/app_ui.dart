import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppUi {
  static const Color primaryGreen = Color(0xFF168A36);
  static const Color darkGreen = Color(0xFF0F6F2B);
  static const Color lightGreen = Color(0xFF2EAD4B);
  static const Color softGreen = Color(0xFFEAF7EE);
  static const Color lineGreen = Color(0xFFCDE8D4);
  static const Color textPrimary = Color(0xFF1F2933);
  static const Color textSecondary = Color(0xFF667085);

  static final NumberFormat _moneyFormatter = NumberFormat("#,###", "vi_VN");

  static String money(num value) {
    return "${_moneyFormatter.format(value)} ₫";
  }

  static Color pageBackground(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  static Color panelColor(BuildContext context) {
    return Theme.of(context).cardColor;
  }

  static Color borderColor(BuildContext context) {
    return Theme.of(context).dividerColor;
  }

  static Color primaryText(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color secondaryText(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return onSurface.withValues(alpha: 0.68);
  }
}

class AppPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.04,
            ),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SummaryMetricCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;

  const SummaryMetricCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppUi.secondaryText(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const AppSectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppUi.primaryText(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class AppNavTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const AppNavTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppUi.primaryText(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppUi.secondaryText(context)),
              ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppUi.secondaryText(context),
        ),
      ),
    );
  }
}
