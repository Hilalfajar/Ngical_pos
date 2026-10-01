import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app.dart';
import '../theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    final sw = MediaQuery.of(context).size.width;
    
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              title: 'Manajemen',
              subtitle: 'Kelola pengaturan dan data aplikasi',
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: sw > 800 ? 700 : double.infinity),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    children: [
                      _MenuListTile(
                        icon: Icons.storefront_rounded,
                        title: 'Pengaturan Toko',
                        subtitle: 'Ubah nama, alamat, dan profil usaha',
                        color: Colors.blue,
                        onTap: () => a.setTab('Settings'),
                      ),
                      _MenuListTile(
                        icon: Icons.people_outline_rounded,
                        title: 'Manajemen Staff',
                        subtitle: 'Kelola akun kasir dan hak akses',
                        color: Colors.orange,
                        onTap: () => a.setTab('Staff'),
                      ),
                      _MenuListTile(
                        icon: Icons.print_rounded,
                        title: 'Pengaturan Printer',
                        subtitle: 'Setelan cetak struk dan koneksi printer',
                        color: Colors.teal,
                        onTap: () => a.setTab('Printer'),
                      ),
                      _MenuListTile(
                        icon: Icons.backup_rounded,
                        title: 'Backup & Restore',
                        subtitle: 'Cadangkan data atau pulihkan dari file',
                        color: Colors.indigo,
                        onTap: () => a.setTab('Backup'),
                      ),
                      _MenuListTile(
                        icon: Icons.info_outline_rounded,
                        title: 'Tentang Aplikasi',
                        subtitle: 'Informasi versi dan pengembang',
                        color: Colors.purple,
                        onTap: () => a.setTab('About'),
                      ),
                    ],
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

class _MenuListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.borderSoft),
        boxShadow: cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: C.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: C.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: C.faint.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
