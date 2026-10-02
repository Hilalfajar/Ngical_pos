import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app.dart';
import '../theme.dart';
import '../utils/toast.dart';

/// Dialog / bottom sheet login PIN staff (bisa dipanggil dari mana saja)
Future<void> showStaffLoginSheet(BuildContext context) async {
  final a = context.read<App>();
  final aktif = a.staffList.where((s) => s.aktif).toList();
  if (aktif.isEmpty) {
    AppToast.error(context, 'Belum ada user. Buat user di menu Staff dulu.');
    return;
  }

  Staff? selected = a.currentStaff != null
      ? aktif.where((s) => s.id == a.currentStaff!.id).firstOrNull ??
          (aktif.length == 1 ? aktif.first : null)
      : (aktif.length == 1 ? aktif.first : null);
  final pinCtrl = TextEditingController();
  bool loading = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final maxW = MediaQuery.sizeOf(ctx).width;
      final sheetW = maxW > 520 ? 480.0 : maxW;
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
              child: Material(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                child: SizedBox(
                  width: sheetW,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        decoration: const BoxDecoration(
                          color: C.brand,
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        child: Row(children: [
                          const Expanded(
                            child: Text('Login Staff',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Pilih User',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: C.muted)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: C.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Staff>(
                            value: selected,
                            isExpanded: true,
                            hint: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('Pilih akun'),
                            ),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            borderRadius: BorderRadius.circular(14),
                            items: aktif
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text('${s.nama} (${s.role})'),
                                    ))
                                .toList(),
                            onChanged: (v) => setSheet(() => selected = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('PIN',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: C.muted)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: pinCtrl,
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
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: loading
                              ? null
                              : () async {
                                  if (selected == null) {
                                    AppToast.error(context, 'Pilih user dulu');
                                    return;
                                  }
                                  if (pinCtrl.text.trim().length < 4) {
                                    AppToast.error(
                                        context, 'PIN minimal 4 digit');
                                    return;
                                  }
                                  setSheet(() => loading = true);
                                  final err = await a.loginStaff(
                                      staffId: selected!.id!,
                                      pin: pinCtrl.text.trim());
                                  if (!ctx.mounted) return;
                                  setSheet(() => loading = false);
                                  if (err != null) {
                                    AppToast.error(context, err);
                                  } else {
                                    Navigator.pop(ctx);
                                    AppToast.success(context,
                                        'Login sebagai ${selected!.nama}');
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: C.brand,
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white))
                              : const Text('Login',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
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

/// Tombol user di SideRail (PC) - di atas ikon Pengaturan
class StaffRailButton extends StatelessWidget {
  final bool expanded;
  const StaffRailButton({super.key, required this.expanded});

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    // Tampilkan jika ada staff ATAU mode staff aktif
    if (a.staffList.isEmpty && !a.staffModeEnabled) {
      return const SizedBox.shrink();
    }

    final loggedIn = a.isStaffLoggedIn;
    final name = loggedIn ? a.currentStaff!.nama : 'Login';
    final role = loggedIn ? a.currentStaff!.role : 'Staff';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      child: Material(
        color: loggedIn ? C.success.withOpacity(0.1) : C.brandLight,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            if (loggedIn) {
              // Menu: ganti user / logout
              final choice = await showModalBottomSheet<String>(
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('$name ($role)',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.swap_horiz_rounded,
                            color: C.brand),
                        title: const Text('Ganti User'),
                        onTap: () => Navigator.pop(ctx, 'switch'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout_rounded,
                            color: C.danger),
                        title: const Text('Logout',
                            style: TextStyle(color: C.danger)),
                        onTap: () => Navigator.pop(ctx, 'logout'),
                      ),
                    ]),
                  ),
                ),
              );
              if (!context.mounted) return;
              if (choice == 'logout') {
                a.logoutStaff();
                AppToast.success(context, 'Berhasil logout');
              } else if (choice == 'switch') {
                await showStaffLoginSheet(context);
              }
            } else {
              await showStaffLoginSheet(context);
            }
          },
          child: SizedBox(
            height: 44,
            width: double.infinity,
            child: expanded
                ? Row(children: [
                    const SizedBox(width: 10),
                    Icon(
                      loggedIn
                          ? Icons.account_circle_rounded
                          : Icons.login_rounded,
                      size: 20,
                      color: loggedIn ? C.success : C.brand,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: loggedIn ? C.success : C.brand,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ])
                : Center(
                    child: Icon(
                      loggedIn
                          ? Icons.account_circle_rounded
                          : Icons.login_rounded,
                      size: 20,
                      color: loggedIn ? C.success : C.brand,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Chip login di bottom nav (HP) - baris kecil di atas nav
class StaffMobileChip extends StatelessWidget {
  const StaffMobileChip({super.key});

  @override
  Widget build(BuildContext context) {
    final a = context.watch<App>();
    if (a.staffList.isEmpty && !a.staffModeEnabled) {
      return const SizedBox.shrink();
    }
    final loggedIn = a.isStaffLoggedIn;

    return Material(
      color: loggedIn ? C.success.withOpacity(0.12) : C.brandLight,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          if (loggedIn) {
            final choice = await showModalBottomSheet<String>(
              context: context,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        '${a.currentStaff!.nama} (${a.currentStaff!.role})',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 12),
                    ListTile(
                      leading:
                          const Icon(Icons.swap_horiz_rounded, color: C.brand),
                      title: const Text('Ganti User'),
                      onTap: () => Navigator.pop(ctx, 'switch'),
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.logout_rounded, color: C.danger),
                      title: const Text('Logout',
                          style: TextStyle(color: C.danger)),
                      onTap: () => Navigator.pop(ctx, 'logout'),
                    ),
                  ]),
                ),
              ),
            );
            if (!context.mounted) return;
            if (choice == 'logout') {
              a.logoutStaff();
              AppToast.success(context, 'Berhasil logout');
            } else if (choice == 'switch') {
              await showStaffLoginSheet(context);
            }
          } else {
            await showStaffLoginSheet(context);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              loggedIn ? Icons.account_circle_rounded : Icons.login_rounded,
              size: 16,
              color: loggedIn ? C.success : C.brand,
            ),
            const SizedBox(width: 6),
            Text(
              loggedIn ? a.currentStaff!.nama : 'Login Staff',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: loggedIn ? C.success : C.brand,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
