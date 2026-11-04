import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app.dart';
import '../widgets/bottom_nav.dart';
import '../theme.dart';
import 'kasir.dart';
import 'produk.dart';
import 'update_stok.dart';
import 'laporan.dart';
import 'simple.dart';
import 'printer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cek jadwal backup otomatis pas app diminimize/ditutup  ini momen
    // yang paling representatif buat "tutup toko".
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      context.read<App>().checkAndRunScheduledBackupIfDue();
    }
  }

  Widget _page(String tab) {
    switch (tab) {
      case 'POS':
        return const KasirPage();
      case 'Produk':
        return const ProdukPage();
      case 'UpdateStok':
        return const UpdateStokMenuPage();
      case 'Transaksi':
        return const LaporanPage();
      case 'About':
        return const AboutPage();
      case 'Settings':
        return const SettingsPage();
      case 'SettingsMenu':
        return const SettingsMenuPage();
      case 'Backup':
        return const BackupPage();
      case 'Printer':
        return const PrinterPage();
      default:
        return const KasirPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();

    // Navigasi back sistem:
    // - Settings detail (Printer/Backup/About/Settings) → SettingsMenu
    // - SettingsMenu / Produk / Transaksi → POS
    // - POS → keluar app
    const settingsDetail = {
      'Settings',
      'Printer',
      'Backup',
      'About',
    };
    return PopScope(
      canPop: a.tab == 'POS',
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (settingsDetail.contains(a.tab)) {
          a.setTab('SettingsMenu');
        } else if (a.tab != 'POS') {
          a.setTab('POS');
        }
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth > 900;
            if (isTablet) {
              // Desktop/tablet: rail kiri + konten (tanpa bottom nav)
              return Row(
                children: [
                  const SideRail(),
                  Container(width: 1, color: C.borderSoft),
                  Expanded(child: _page(a.tab)),
                ],
              );
            }
            // HP: konten + bottom nav overlay
            return Stack(children: [
              Positioned.fill(child: _page(a.tab)),
              const BottomNav(),
            ]);
          },
        ),
      ),
    );
  }
}
