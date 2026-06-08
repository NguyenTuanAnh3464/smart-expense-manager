import 'package:flutter/material.dart';

import '../services/theme_service.dart';

class ThemeSettingScreen extends StatefulWidget {
  const ThemeSettingScreen({super.key});

  @override
  State<ThemeSettingScreen> createState() => _ThemeSettingScreenState();
}

class _ThemeSettingScreenState extends State<ThemeSettingScreen> {
  late int selectedIndex;

  final themes = AppThemePreset.values;

  @override
  void initState() {
    super.initState();
    selectedIndex = themes.indexOf(ThemeService.instance.preset);
    if (selectedIndex < 0) selectedIndex = 0;
  }

  AppThemePreset get selectedTheme => themes[selectedIndex];

  void previousTheme() {
    setState(() {
      selectedIndex = (selectedIndex - 1 + themes.length) % themes.length;
    });
  }

  void nextTheme() {
    setState(() {
      selectedIndex = (selectedIndex + 1) % themes.length;
    });
  }

  Future<void> saveTheme() async {
    await ThemeService.instance.setThemePreset(selectedTheme);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Đã lưu màu chủ đề")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ThemePreviewPalette.fromPreset(selectedTheme);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Thiết lập màu chủ đề",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: previousTheme,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: "Theme trước",
                  ),
                  Expanded(
                    child: Text(
                      selectedTheme.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: nextTheme,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: "Theme tiếp theo",
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _ThemePreview(
                  key: ValueKey(selectedTheme.id),
                  palette: palette,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < themes.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: i == selectedIndex ? 18 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: i == selectedIndex
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: saveTheme,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Hoàn thành thiết lập",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  final _ThemePreviewPalette palette;

  const _ThemePreview({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            children: [
              _SegmentPreview(palette: palette),
              const SizedBox(height: 14),
              _PreviewPanel(
                palette: palette,
                children: [
                  _PreviewRow(
                    palette: palette,
                    label: "Date",
                    value: "08/06/2026",
                    icon: Icons.event,
                  ),
                  _PreviewRow(
                    palette: palette,
                    label: "Note",
                    value: "Ghi chú",
                    icon: Icons.notes_outlined,
                  ),
                  _PreviewRow(
                    palette: palette,
                    label: "Expense amount",
                    value: "500,000đ",
                    icon: Icons.payments_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Category",
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.08,
                children: _previewCategories.map((category) {
                  return Container(
                    decoration: BoxDecoration(
                      color: palette.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(category.icon, color: category.color, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          category.label,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentPreview extends StatelessWidget {
  final _ThemePreviewPalette palette;

  const _SegmentPreview({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: palette.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                "Expense",
                style: TextStyle(
                  color: palette.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                "Income",
                style: TextStyle(
                  color: palette.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  final _ThemePreviewPalette palette;
  final List<Widget> children;

  const _PreviewPanel({required this.palette, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, color: palette.border),
          ],
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final _ThemePreviewPalette palette;
  final String label;
  final String value;
  final IconData icon;

  const _PreviewRow({
    required this.palette,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: palette.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(value, style: TextStyle(color: palette.mutedText)),
        ],
      ),
    );
  }
}

class _ThemePreviewPalette {
  final Color background;
  final Color card;
  final Color primary;
  final Color onPrimary;
  final Color text;
  final Color mutedText;
  final Color border;

  const _ThemePreviewPalette({
    required this.background,
    required this.card,
    required this.primary,
    required this.onPrimary,
    required this.text,
    required this.mutedText,
    required this.border,
  });

  factory _ThemePreviewPalette.fromPreset(AppThemePreset preset) {
    return switch (preset) {
      AppThemePreset.forestGreen => const _ThemePreviewPalette(
        background: Color(0xFFEFFAF4),
        card: Colors.white,
        primary: Color(0xFF36B889),
        onPrimary: Colors.white,
        text: Color(0xFF1F2933),
        mutedText: Color(0xFF667085),
        border: Color(0xFFCDEBDB),
      ),
      AppThemePreset.monotoneBlack => const _ThemePreviewPalette(
        background: Color(0xFF0B0B0D),
        card: Color(0xFF1E1E22),
        primary: Color(0xFFB9BDC6),
        onPrimary: Color(0xFF101014),
        text: Color(0xFFE7E9EE),
        mutedText: Color(0xFFB3B6BE),
        border: Color(0xFF36363A),
      ),
      AppThemePreset.lightGreen => const _ThemePreviewPalette(
        background: Color(0xFFEAF7EE),
        card: Colors.white,
        primary: Color(0xFF168A36),
        onPrimary: Colors.white,
        text: Color(0xFF1F2933),
        mutedText: Color(0xFF667085),
        border: Color(0xFFCDE8D4),
      ),
    };
  }
}

class _PreviewCategory {
  final String label;
  final IconData icon;
  final Color color;

  const _PreviewCategory(this.label, this.icon, this.color);
}

const _previewCategories = [
  _PreviewCategory("Food", Icons.restaurant, Colors.orange),
  _PreviewCategory("Houseware", Icons.home_outlined, Colors.brown),
  _PreviewCategory("Clothes", Icons.checkroom, Colors.blue),
  _PreviewCategory("Transportation", Icons.directions_bus, Colors.deepOrange),
  _PreviewCategory("Cosmetic", Icons.brush, Colors.pink),
  _PreviewCategory("Exchange", Icons.currency_exchange, Colors.teal),
  _PreviewCategory("Education", Icons.school, Colors.redAccent),
  _PreviewCategory("Electric bill", Icons.flash_on, Colors.amber),
  _PreviewCategory("Medical", Icons.local_hospital, Colors.green),
];
