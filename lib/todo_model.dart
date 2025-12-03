class TodoModel {
  final String id;
  String name;
  DateTime deadline;
  final DateTime createdAt;
  bool isCompleted;

  TodoModel({
    required this.id,
    required this.name,
    required this.deadline,
    DateTime? createdAt,
    this.isCompleted = false,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Memverifikasi validitas temporal tugas terhadap waktu sekarang.
  bool isExpired() {
    return DateTime.now().isAfter(deadline) && !isCompleted;
  }

  /// Mengkalkulasi delta waktu secara real-time.
  Duration getRemainingTime() {
    return deadline.difference(DateTime.now());
  }

  /// Menghasilkan representasi tekstual waktu yang ergonomis bagi pengguna.
  String getCountdownText() {
    if (isCompleted) return 'Selesai';
    if (isExpired()) return 'TERLAMBAT';

    final remaining = getRemainingTime();
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;

    if (days > 0) {
      return '$days hari $hours jam';
    } else if (hours > 0) {
      return '$hours jam $minutes menit';
    } else if (minutes > 0) {
      return '$minutes menit $seconds detik';
    } else {
      return '$seconds detik';
    }
  }

  // --- IMPLEMENTASI SERIALISASI JSON ---

  /// Mengubah instance objek menjadi Map (format JSON) untuk penyimpanan.
  /// Data DateTime dikonversi menjadi format ISO-8601 string agar aman disimpan.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'deadline': deadline.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  /// Membangun kembali objek dari Map (hasil decode JSON).
  /// Digunakan saat mengambil data dari penyimpanan lokal.
  factory TodoModel.fromMap(Map<String, dynamic> map) {
    return TodoModel(
      id: map['id'],
      name: map['name'],
      deadline: DateTime.parse(map['deadline']),
      createdAt: DateTime.parse(map['createdAt']),
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}
