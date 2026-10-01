import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app.dart';
import '../theme.dart';

class AppDrawer extends StatelessWidget {
  final void Function(String) onNav;
  const AppDrawer({super.key, required this.onNav});

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    return Drawer(
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: Column(
        children: [
          //  Header 
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              22,
              MediaQuery.of(context).padding.top + 20,
              22,
              24,
            ),
            decoration: const BoxDecoration(
              color: C.brand,
              borderRadius: BorderRadius.only(
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.point_of_sale_rounded,
                          color: C.brand, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.storeName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a.storeAddress.isEmpty
                                ? 'Alamat belum diisi'
                                : a.storeAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Halo, ${a.ownerName.isEmpty ? 'Pemilik' : a.ownerName}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Manager',
                        style: TextStyle(
                          color: Color(0xFF78350F),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          //  Menu items 
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
              children: [
                const SectionLabel('Utama'),
                _DrawerItem(
                  icon: Icons.point_of_sale_rounded,
                  title: 'Kasir',
                  subtitle: 'Point of Sale',
                  onTap: () => onNav('POS'),
                ),
                _DrawerItem(
                  icon: Icons.receipt_long_rounded,
                  title: 'Transaksi',
                  subtitle: 'Riwayat penjualan',
                  onTap: () => onNav('Transaksi'),
                ),
                _DrawerItem(
                  icon: Icons.inventory_2_rounded,
                  title: 'Produk',
                  subtitle: 'Kelola produk & stok',
                  onTap: () => onNav('Produk'),
                ),
                _DrawerItem(
                  icon: Icons.add_box_outlined,
                  title: 'Update Stok',
                  subtitle: 'Tambah stok & riwayat',
                  onTap: () => onNav('UpdateStok'),
                ),
                const SizedBox(height: 12),
                const SectionLabel('Lainnya'),
                _DrawerItem(
                  icon: Icons.print_rounded,
                  title: 'Printer',
                  subtitle: 'Pengaturan printer',
                  onTap: () => onNav('Printer'),
                ),
                _DrawerItem(
                  icon: Icons.info_outline_rounded,
                  title: 'Tentang',
                  subtitle: 'Info aplikasi',
                  onTap: () => onNav('About'),
                ),
                const SizedBox(height: 12),
                const SectionLabel('Manajemen'),
                _DrawerItem(
                  icon: Icons.storefront_rounded,
                  title: 'Pengaturan Toko',
                  subtitle: 'Nama, alamat, kontak',
                  onTap: () => onNav('Settings'),
                ),
                _DrawerItem(
                  icon: Icons.people_outline_rounded,
                  title: 'Staff',
                  subtitle: 'Kelola karyawan',
                  onTap: () => onNav('Staff'),
                ),
                _DrawerItem(
                  icon: Icons.backup_rounded,
                  title: 'Backup & Restore',
                  subtitle: 'Cadangan data',
                  onTap: () => onNav('Backup'),
                ),
              ],
            ),
          ),

          //  Footer 
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
            child: Column(
              children: [
                Material(
                  color: C.dangerSoft,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFECACA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.logout_rounded,
                                color: C.danger, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Tutup Menu',
                            style: TextStyle(
                              color: C.danger,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Ngical v1.0.0',
                  style: TextStyle(
                    color: C.faint.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.borderSoft),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: C.brandLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: C.brand, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: C.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: C.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: C.faint.withOpacity(0.6), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
