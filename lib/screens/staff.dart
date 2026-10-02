import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app.dart';
import '../theme.dart';
import '../utils/toast.dart';
import '../widgets/staff_session.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});
  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  Future<void> _showForm({Staff? staff}) async {
    final a = context.read<App>();

    if (a.hasManager && !a.isManagerLoggedIn) {
      AppToast.error(context, 'Login sebagai Manager untuk mengelola user.');
      await showStaffLoginSheet(context);
      return;
    }

    final nama = TextEditingController(text: staff?.nama ?? '');
    final pin = TextEditingController(text: staff?.pin ?? '');
    String role = staff?.role ?? (a.hasManager ? 'Kasir' : 'Manager');
    bool aktif = staff?.aktif ?? true;
    final selectedPerms = <String>{
      ...(staff?.permissions.isNotEmpty == true
          ? staff!.permissions
          : Staff.defaultPermissions(role)),
    };

    final forceManager = !a.hasManager && staff == null;

    const menuOptions = <MapEntry<String, String>>[
      MapEntry('pos', 'Kasir (POS)'),
      MapEntry('produk', 'Produk'),
      MapEntry('laporan', 'Laporan'),
      MapEntry('printer', 'Printer'),
      MapEntry('backup', 'Backup'),
      MapEntry('settings', 'Pengaturan Toko'),
      MapEntry('staff', 'Kelola Staff'),
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final maxW = MediaQuery.sizeOf(ctx).width;
        final sheetW = maxW > 520 ? 480.0 : maxW;
        final viewInsets = MediaQuery.viewInsetsOf(ctx).bottom;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: viewInsets),
                child: Material(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  child: SizedBox(
                    width: sheetW,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: C.border,
                                    borderRadius: BorderRadius.circular(2)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _sheetHeader(
                              ctx,
                              staff == null
                                  ? (forceManager
                                      ? 'Buat Manager Pertama'
                                      : 'Tambah User')
                                  : 'Edit User',
                            ),
                            const SizedBox(height: 20),
                            _label('Nama'),
                            TextField(
                              controller: nama,
                              decoration: const InputDecoration(
                                hintText: 'Nama lengkap',
                                prefixIcon: Icon(Icons.person_outline,
                                    size: 18, color: C.muted),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _label('Role / Jabatan'),
                            Container(
                              decoration: BoxDecoration(
                                color: C.surface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: forceManager ? 'Manager' : role,
                                  isExpanded: true,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  borderRadius: BorderRadius.circular(14),
                                  items: (forceManager
                                          ? ['Manager']
                                          : ['Kasir', 'Admin', 'Manager'])
                                      .map((r) => DropdownMenuItem(
                                          value: r, child: Text(r)))
                                      .toList(),
                                  onChanged: forceManager
                                      ? null
                                      : (v) {
                                          setSheet(() {
                                            role = v!;
                                            selectedPerms
                                              ..clear()
                                              ..addAll(Staff.defaultPermissions(
                                                  role));
                                          });
                                        },
                                ),
                              ),
                            ),
                            if (forceManager) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Akun pertama harus Manager agar bisa mengaktifkan Mode Staff.',
                                style: TextStyle(
                                    fontSize: 12, color: C.muted, height: 1.4),
                              ),
                            ],
                            const SizedBox(height: 16),
                            _label('PIN (4-6 digit)'),
                            TextField(
                              controller: pin,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 6,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: const InputDecoration(
                                hintText: '••••',
                                prefixIcon: Icon(Icons.lock_outline,
                                    size: 18, color: C.muted),
                                counterText: '',
                              ),
                            ),
                            if (role != 'Manager') ...[
                              const SizedBox(height: 16),
                              _label('Menu yang boleh dibuka'),
                              const SizedBox(height: 4),
                              ...menuOptions.map((e) {
                                final checked = selectedPerms.contains(e.key);
                                return CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(e.value,
                                      style: const TextStyle(fontSize: 14)),
                                  value: checked,
                                  activeColor: C.brand,
                                  onChanged: (v) {
                                    setSheet(() {
                                      if (v == true) {
                                        selectedPerms.add(e.key);
                                      } else {
                                        selectedPerms.remove(e.key);
                                      }
                                    });
                                  },
                                );
                              }),
                            ],
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: C.surface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(children: [
                                const Icon(Icons.toggle_on_outlined,
                                    size: 20, color: C.muted),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text('Status Aktif',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                ),
                                Switch(
                                  value: aktif,
                                  onChanged: (v) => setSheet(() => aktif = v),
                                  activeColor: C.brand,
                                ),
                              ]),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 48,
                              child: FilledButton(
                                onPressed: () async {
                                  final n = nama.text.trim();
                                  final p = pin.text.trim();
                                  if (n.isEmpty || p.length < 4) {
                                    AppToast.error(context,
                                        'Nama dan PIN minimal 4 digit wajib diisi');
                                    return;
                                  }
                                  final finalRole =
                                      forceManager ? 'Manager' : role;
                                  final s = Staff(
                                    id: staff?.id,
                                    nama: n,
                                    pin: p,
                                    role: finalRole,
                                    aktif: aktif,
                                    permissions: finalRole == 'Manager'
                                        ? Staff.defaultPermissions('Manager')
                                        : selectedPerms.toList(),
                                  );
                                  final err = await a.saveStaff(s);
                                  if (!mounted) return;
                                  if (err != null) {
                                    AppToast.error(context, err);
                                    return;
                                  }
                                  Navigator.pop(ctx);
                                  AppToast.success(
                                      context,
                                      staff == null
                                          ? 'User ditambahkan'
                                          : 'User diperbarui');
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: C.brand,
                                ),
                                child: const Text('Simpan',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleMode(bool value) async {
    final a = context.read<App>();
    if (!a.isManagerLoggedIn) {
      AppToast.error(
          context, 'Login sebagai Manager untuk mengubah Mode Staff.');
      await showStaffLoginSheet(context);
      return;
    }
    final err = await a.setStaffModeEnabled(value);
    if (!mounted) return;
    if (err != null) {
      AppToast.error(context, err);
      return;
    }
    AppToast.success(
        context,
        value
            ? 'Mode Staff aktif. Login diperlukan untuk Kasir, Produk, Laporan.'
            : 'Mode Staff dimatikan. Semua menu bebas.');
  }

  Future<void> _onTambahPressed() async {
    final a = context.read<App>();
    if (a.hasManager && !a.isManagerLoggedIn) {
      AppToast.error(context, 'Login sebagai Manager untuk menambah user.');
      await showStaffLoginSheet(context);
      return;
    }
    await _showForm();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    final canManage = !a.hasManager || a.isManagerLoggedIn;

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            children: [
              PageHeader(
                title: 'Staff',
                subtitle: a.staffModeEnabled
                    ? (a.isStaffLoggedIn
                        ? 'Login: ${a.currentStaff!.nama} (${a.currentStaff!.role})'
                        : 'Mode Staff aktif, login diperlukan')
                    : 'Mode Staff nonaktif (opsional)',
                trailing: canManage
                    ? FilledButton.icon(
                        onPressed: _onTambahPressed,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Tambah User'),
                        style: FilledButton.styleFrom(
                          backgroundColor: C.brand,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              if (a.hasManager) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: a.staffModeEnabled
                        ? const Color(0xFFFFF3E0)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: a.staffModeEnabled
                          ? const Color(0xFFFFB74D)
                          : C.borderSoft,
                    ),
                  ),
                  child: Row(children: [
                    Icon(
                      a.staffModeEnabled
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      color: a.staffModeEnabled
                          ? const Color(0xFFF57C00)
                          : C.muted,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mode Staff',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                            a.staffModeEnabled
                                ? 'ON - Kasir/Produk/Laporan perlu login'
                                : 'OFF - semua menu bebas (default)',
                            style: const TextStyle(
                                fontSize: 12, color: C.muted, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: a.staffModeEnabled,
                      onChanged: (v) => _toggleMode(v),
                      activeColor: C.brand,
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
              if (!a.hasManager)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: C.brandLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline_rounded, color: C.brand, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Belum ada Manager. Tekan "Tambah User" untuk membuat akun Manager pertama. Setelah ada Manager, kelola user wajib login Manager.',
                        style: TextStyle(
                            color: C.brand, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ]),
                )
              else if (!a.isManagerLoggedIn)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.lock_outline_rounded,
                        color: Color(0xFFF57C00), size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Pengaturan user terkunci. Login sebagai Manager untuk menambah / edit / hapus user.',
                        style: TextStyle(
                            color: Color(0xFFE65100),
                            fontSize: 12,
                            height: 1.4),
                      ),
                    ),
                    TextButton(
                      onPressed: () => showStaffLoginSheet(context),
                      child: const Text('Login',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF57C00))),
                    ),
                  ]),
                ),
              const SizedBox(height: 16),
              if (a.staffList.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 48, color: C.faint),
                      SizedBox(height: 12),
                      Text('Belum ada user', style: TextStyle(color: C.muted)),
                      SizedBox(height: 4),
                      Text('Tekan "Tambah User" untuk mulai',
                          style: TextStyle(color: C.faint, fontSize: 12)),
                    ],
                  ),
                )
              else
                ...a.staffList.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _StaffCard(
                        staff: s,
                        canManage: canManage,
                        onEdit: canManage ? () => _showForm(staff: s) : null,
                        onDelete: canManage
                            ? () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    title: const Text('Hapus user?'),
                                    content: Text(
                                        '${s.nama} akan dihapus permanen.'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Batal')),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Hapus',
                                              style:
                                                  TextStyle(color: C.danger))),
                                    ],
                                  ),
                                );
                                if (ok == true && mounted) {
                                  final err = await a.deleteStaffById(s.id!);
                                  if (!mounted) return;
                                  if (err != null) {
                                    AppToast.error(context, err);
                                  } else {
                                    AppToast.success(context, 'User dihapus');
                                  }
                                }
                              }
                            : null,
                        onToggleAktif: canManage
                            ? () async {
                                final err = await a
                                    .saveStaff(s.copyWith(aktif: !s.aktif));
                                if (!mounted) return;
                                if (err != null) {
                                  AppToast.error(context, err);
                                }
                              }
                            : null,
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetHeader(BuildContext ctx, String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(
        color: C.brand,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
        IconButton(
          onPressed: () => Navigator.pop(ctx),
          icon: const Icon(Icons.close, color: Colors.white, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  static Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: C.muted)),
      );
}

class _StaffCard extends StatelessWidget {
  final Staff staff;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleAktif;

  const _StaffCard({
    required this.staff,
    required this.canManage,
    this.onEdit,
    this.onDelete,
    this.onToggleAktif,
  });

  Color get _roleColor {
    switch (staff.role) {
      case 'Manager':
        return Colors.purple;
      case 'Admin':
        return C.warning;
      default:
        return C.brand;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.borderSoft),
          boxShadow: cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _roleColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                staff.nama.isNotEmpty ? staff.nama[0].toUpperCase() : '?',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _roleColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(staff.nama,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: C.text)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _roleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(staff.role,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _roleColor)),
                  ),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: staff.aktif ? C.success : C.faint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(staff.aktif ? 'Aktif' : 'Nonaktif',
                      style: TextStyle(
                          fontSize: 12,
                          color: staff.aktif ? C.success : C.faint)),
                ]),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit?.call();
                if (v == 'toggle') onToggleAktif?.call();
                if (v == 'delete') onDelete?.call();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ])),
                PopupMenuItem(
                    value: 'toggle',
                    child: Row(children: [
                      Icon(
                        staff.aktif
                            ? Icons.block_rounded
                            : Icons.check_circle_outline,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(staff.aktif ? 'Nonaktifkan' : 'Aktifkan'),
                    ])),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 16, color: C.danger),
                      SizedBox(width: 8),
                      Text('Hapus', style: TextStyle(color: C.danger)),
                    ])),
              ],
              icon: const Icon(Icons.more_vert, color: C.muted, size: 20),
            ),
        ]),
      ),
    );
  }
}
