import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app.dart';
import '../theme.dart';
import 'staff_session.dart';

/// Navigasi utama:
/// - HP: bottom bar (dengan pill Menu di POS)
/// - Tablet/PC: rail vertikal kiri (collapse/expand)
class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    if (a.sheetOpen) return const SizedBox.shrink();

    final bottom = MediaQuery.of(context).padding.bottom;
    final isPos = a.tab == 'POS';
    final expanded = a.navExpanded;
    final sw = MediaQuery.of(context).size.width;
    final isTablet = sw > 900;

    if (isTablet) return const SizedBox.shrink();

    final navHeight = sw > 600 ? 56.0 : 52.0;

    if (isPos && !expanded) {
      // Collapsed: hanya tampilkan tombol ^ floating
      return Positioned(
        left: 0,
        right: 0,
        bottom: 2 + bottom,
        child: Center(
          child: _ToggleButton(expanded: false, onTap: a.expandNav),
        ),
      );
    }

    const settingsTabs = {
      'SettingsMenu',
      'Settings',
      'Printer',
      'Staff',
      'Backup',
      'About',
    };
    final isSettingsActive = settingsTabs.contains(a.tab);

    return Positioned(
      left: 12,
      right: 12,
      bottom: 8 + bottom,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const StaffMobileChip(),
              const SizedBox(height: 6),
              // Tombol ^ di atas nav bar saat di POS
              if (isPos) ...[
                Center(
                    child: _ToggleButton(expanded: true, onTap: a.collapseNav)),
                const SizedBox(height: 0),
              ],
              Container(
                height: navHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (a.canAccessMenu('POS'))
                      _NavItem(
                        icon: Icons.point_of_sale_rounded,
                        label: 'Kasir',
                        active: a.tab == 'POS',
                        onTap: () {
                          if (!isPos) {
                            a.setTab('POS');
                          }
                          // Jika sudah di POS, tidak lakukan apa-apa
                        },
                      ),
                    if (a.canAccessMenu('Produk'))
                      _NavItem(
                        icon: Icons.inventory_2_rounded,
                        label: 'Produk',
                        active: a.tab == 'Produk',
                        onTap: () => a.setTab('Produk'),
                      ),
                    if (a.canAccessMenu('UpdateStok'))
                      _NavItem(
                        icon: Icons.add_box_outlined,
                        label: 'Stok',
                        active: a.tab == 'UpdateStok',
                        onTap: () => a.setTab('UpdateStok'),
                      ),
                    if (a.canAccessMenu('Transaksi'))
                      _NavItem(
                        icon: Icons.bar_chart_rounded,
                        label: 'Laporan',
                        active: a.tab == 'Transaksi',
                        onTap: () => a.setTab('Transaksi'),
                      ),
                    if (a.canAccessMenu('SettingsMenu'))
                      _NavItem(
                        icon: Icons.settings_rounded,
                        label: 'Pengaturan',
                        active: isSettingsActive,
                        onTap: () {
                          a.setTab('SettingsMenu');
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;
  const _ToggleButton({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.brand.withValues(alpha: 0.7),
      elevation: 4,
      shadowColor: Colors.black12,
      shape: const StadiumBorder(),
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: const Icon(Icons.keyboard_arrow_up_rounded,
                  size: 18, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rail vertikal tablet/PC: state disimpan di App agar tidak hilang saat rebuild
class SideRail extends StatelessWidget {
  const SideRail({super.key});

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    final expanded = a.railExpanded;
    const settingsTabs = {
      'SettingsMenu',
      'Settings',
      'Printer',
      'Staff',
      'Backup',
      'About',
    };
    final isSettingsActive = settingsTabs.contains(a.tab);
    final top = MediaQuery.of(context).padding.top;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: expanded ? 156 : 58,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: C.borderSoft)),
      ),
      child: Column(
        children: [
          SizedBox(height: top + 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: C.brand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.point_of_sale_rounded,
                      color: Colors.white, size: 20),
                ),
                if (expanded) ...[
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Ngical',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: C.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Material(
              color: C.surface,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => context.read<App>().toggleRailExpanded(),
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 36,
                  width: double.infinity,
                  child: expanded
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.keyboard_double_arrow_left_rounded,
                                size: 18, color: C.muted),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Collapse',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: C.muted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : const Icon(
                          Icons.keyboard_double_arrow_right_rounded,
                          size: 18,
                          color: C.muted,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (a.canAccessMenu('POS'))
            _RailItem(
              icon: Icons.point_of_sale_rounded,
              label: 'Kasir',
              active: a.tab == 'POS',
              expanded: expanded,
              onTap: () => a.setTab('POS'),
            ),
          if (a.canAccessMenu('Produk'))
            _RailItem(
              icon: Icons.inventory_2_rounded,
              label: 'Produk',
              active: a.tab == 'Produk',
              expanded: expanded,
              onTap: () => a.setTab('Produk'),
            ),
          if (a.canAccessMenu('UpdateStok'))
            _RailItem(
              icon: Icons.add_box_outlined,
              label: 'Stok',
              active: a.tab == 'UpdateStok',
              expanded: expanded,
              onTap: () => a.setTab('UpdateStok'),
            ),
          if (a.canAccessMenu('Transaksi'))
            _RailItem(
              icon: Icons.bar_chart_rounded,
              label: 'Laporan',
              active: a.tab == 'Transaksi',
              expanded: expanded,
              onTap: () => a.setTab('Transaksi'),
            ),
          const Spacer(),
          // Login / ganti user / logout - selalu di atas gear
          StaffRailButton(expanded: expanded),
          if (a.canAccessMenu('SettingsMenu'))
            _RailItem(
              icon: Icons.settings_rounded,
              label: 'Pengaturan',
              active: isSettingsActive,
              expanded: expanded,
              onTap: () => a.setTab('SettingsMenu'),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      child: Material(
        color: active ? C.brandLight : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 44,
            width: double.infinity,
            child: expanded
                ? Row(
                    children: [
                      const SizedBox(width: 10),
                      Icon(icon, size: 20, color: active ? C.brand : C.faint),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color: active ? C.brand : C.muted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Center(
                    child:
                        Icon(icon, size: 20, color: active ? C.brand : C.faint),
                  ),
          ),
        ),
      ),
    );

    if (!expanded) {
      return Tooltip(
        message: label,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 250),
        verticalOffset: 0,
        margin: const EdgeInsets.only(left: 58),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        child: btn,
      );
    }
    return btn;
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 40,
                height: 26,
                decoration: BoxDecoration(
                  color: active ? C.brandLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: active ? C.brand : C.faint,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? C.brand : C.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
