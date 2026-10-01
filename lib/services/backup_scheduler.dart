import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../providers/app.dart';

/// Nama unik task WorkManager. Cuma SATU task periodik yang dipasang -
/// dia bangun tiap 15 menit (interval minimum WorkManager di Android)
/// dan cek apakah jadwal backup sudah "jatuh tempo", persis logika yang
/// sama dipakai saat app dibuka/ditutup (lihat App.checkAndRunScheduledBackupIfDue).
///
/// Kenapa begini, bukan hitung initialDelay pas per-jadwal: supaya kalau
/// user ganti jam/frekuensi/cakupan di pengaturan, tidak perlu daftar
/// ulang task-nya - cukup baca ulang setting yang tersimpan tiap kali
/// task ini bangun.
const String kAutoBackupTaskName = 'ngical_auto_backup_check';

@pragma('vm:entry-point')
void backupCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final app = App();
      await app.init();
      await app.checkAndRunScheduledBackupIfDue();
    } catch (_) {
      // Jangan sampai isolate background nge-crash/retry-loop kalau ada
      // error tak terduga (mis. storage penuh). Foreground check (pas
      // app dibuka/ditutup) tetap jadi jaring pengaman.
    }
    return Future.value(true);
  });
}

/// Dipanggil sekali di main() sebelum runApp. Aman dipanggil di semua
/// platform - di luar Android cuma no-op (workmanager belum disetup
/// native-nya untuk iOS/desktop di project ini).
Future<void> initBackupScheduler() async {
  if (!Platform.isAndroid) return;
  try {
    await Workmanager().initialize(backupCallbackDispatcher);
  } catch (_) {
    // Kalau gagal init pun, backup tetap jalan lewat foreground check.
  }
}

/// Pasang atau lepas task periodik sesuai status aktif/nonaktif dari
/// pengaturan backup otomatis. Dipanggil tiap kali App.saveBackupSchedule
/// mengubah `enabled`, dan sekali lagi di startup untuk jaga-jaga task-nya
/// belum terdaftar (mis. abis install baru).
Future<void> syncBackupSchedulerRegistration(bool enabled) async {
  if (!Platform.isAndroid) return;
  try {
    if (enabled) {
      await Workmanager().registerPeriodicTask(
        kAutoBackupTaskName,
        kAutoBackupTaskName,
        frequency: const Duration(minutes: 15),
      );
    } else {
      await Workmanager().cancelByUniqueName(kAutoBackupTaskName);
    }
  } catch (_) {
    // Silent - fitur tetap jalan lewat foreground check kalau ini gagal.
  }
}
