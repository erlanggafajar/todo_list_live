import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'todo_model.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  static const AndroidNotificationChannel _deadlineChannel =
      AndroidNotificationChannel(
    'deadline_channel',
    'Pengingat Deadline',
    description: 'Notifikasi menjelang deadline tugas',
    importance: Importance.max,
  );

  // Koleksi data utama
  List<TodoModel> _todos = [];

  // Stream controller untuk manajemen waktu
  late Stream<DateTime> _timeStream;
  Timer? _reminderTimer;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    // Memuat data dari penyimpanan lokal saat inisialisasi
    _loadTasks();
    _initNotifications();

    _timeStream = Stream.periodic(
      const Duration(seconds: 1),
      (_) => DateTime.now(),
    ).asBroadcastStream();

    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkReminders();
    });
  }

  void _showStatusMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  // --- MANAJEMEN PENYIMPANAN LOKAL (PERSISTENCE) ---

  /// Menyimpan seluruh daftar tugas ke SharedPreferences.
  /// Data dikonversi menjadi list of maps, lalu di-encode ke string JSON.
  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    // Mengonversi setiap objek TodoModel menjadi Map
    final List<Map<String, dynamic>> maps =
        _todos.map((todo) => todo.toMap()).toList();
    // Mengubah List Map menjadi String JSON tunggal
    final String jsonString = jsonEncode(maps);

    await prefs.setString('todos_data', jsonString);
  }

  /// Memuat data tugas dari SharedPreferences.
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('todos_data');

    if (jsonString != null) {
      try {
        // Decode string JSON kembali menjadi List objek
        final List<dynamic> decodedList = jsonDecode(jsonString);
        final List<TodoModel> loadedTodos =
            decodedList.map((item) => TodoModel.fromMap(item)).toList();

        setState(() {
          _todos = loadedTodos;
        });
      } catch (e) {
        debugPrint('Error loading tasks: $e');
        // Fallback jika terjadi korupsi data (opsional: bersihkan data)
      }
    }
  }

  // --- LOGIKA BISNIS & Notifikasi ---

  void _checkReminders() {
    for (var todo in _todos) {
      if (!todo.isExpired() && !todo.isCompleted) {
        final remaining = todo.getRemainingTime();
        if (remaining.inMinutes <= 3 && remaining.inMinutes > 2) {
          unawaited(_showLocalNotification(todo, '3 menit lagi!'));
        } else if (remaining.inMinutes <= 2 && remaining.inMinutes > 1) {
          unawaited(_showLocalNotification(todo, '2 menit lagi!'));
        } else if (remaining.inMinutes <= 1 && remaining.inMinutes >= 0) {
          unawaited(_showLocalNotification(todo, 'Segera berakhir!'));
        }
      }
    }
  }

  Future<void> _initNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_deadlineChannel);
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    if (mounted) {
      setState(() {
        _notificationsInitialized = true;
      });
    } else {
      _notificationsInitialized = true;
    }
  }

  Future<void> _showLocalNotification(TodoModel todo, String message) async {
    if (!_notificationsInitialized) return;

    const androidDetails = AndroidNotificationDetails(
      'deadline_channel',
      'Pengingat Deadline',
      channelDescription: 'Notifikasi menjelang deadline tugas',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _notifications.show(
      todo.id.hashCode,
      todo.name,
      message,
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
    );
  }

  double _calculateProgress(TodoModel todo) {
    if (todo.isCompleted) return 1;
    final totalSeconds =
        todo.deadline.difference(todo.createdAt).inSeconds.clamp(1, 1 << 31);
    final remaining = todo.getRemainingTime().inSeconds;
    final elapsed = totalSeconds - remaining;
    final ratio = elapsed / totalSeconds;
    return ratio.clamp(0.0, 1.0);
  }

  Widget _buildProgressBar(TodoModel todo, bool isExpired) {
    final progress = isExpired ? 1.0 : _calculateProgress(todo);
    final color = isExpired
        ? Colors.red
        : progress < 0.5
            ? Colors.green
            : progress < 0.8
                ? Colors.orange
                : Colors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.linear_scale, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              isExpired ? 'Lewat deadline' : 'Progres menuju deadline',
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  void _showHowToUse() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final dialogWidth = width > 480 ? 480.0 : width * 0.95;

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            contentPadding: EdgeInsets.zero,
            content: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: MediaQuery.of(context).size.height * 0.85),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 228, 227, 253),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.help_outline,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Cara Penggunaan',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.only(top: 35),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HowToItem(
                              icon: Icons.add_circle_outline,
                              title: 'Tambah Tugas',
                              description:
                                  'Ketuk tombol "Baru" lalu isi nama, tanggal, dan waktu deadline.',
                            ),
                            SizedBox(height: 20),
                            _HowToItem(
                              icon: Icons.access_time,
                              title: 'Pantau Countdown',
                              description:
                                  'Sisa waktu diperbarui otomatis tiap detik.',
                            ),
                            SizedBox(height: 20),
                            _HowToItem(
                              icon: Icons.notifications_active,
                              title: 'Pengingat Otomatis',
                              description:
                                  'Notifikasi muncul di 3, 2, dan 1 menit sebelum deadline.',
                            ),
                            SizedBox(height: 20),
                            _HowToItem(
                              icon: Icons.swipe,
                              title: 'Hapus Tugas',
                              description:
                                  'Geser item ke kiri atau buka detailnya untuk pilihan hapus.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20)),
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Tutup'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- MANAJEMEN DATA (CRUD) ---

  Future<void> _showTaskDialog({TodoModel? todoToEdit}) async {
    if (todoToEdit != null && todoToEdit.isExpired()) {
      _showStatusMessage(
          'Tugas sudah melewati deadline dan tidak dapat diedit.');
      return;
    }

    final isEditing = todoToEdit != null;
    final nameController = TextEditingController(
      text: isEditing ? todoToEdit.name : '',
    );
    DateTime selectedDate = isEditing ? todoToEdit.deadline : DateTime.now();
    TimeOfDay selectedTime = isEditing
        ? TimeOfDay.fromDateTime(todoToEdit.deadline)
        : TimeOfDay.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Perbarui Tugas' : 'Tugas Baru',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  autofocus: !isEditing,
                  decoration: InputDecoration(
                    labelText: 'Nama Tugas',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    prefixIcon: const Icon(Icons.task_alt_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildPickerButton(
                        icon: Icons.calendar_today,
                        label:
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 1),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (d != null) setModalState(() => selectedDate = d);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPickerButton(
                        icon: Icons.access_time,
                        label: selectedTime.format(context),
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (t != null) setModalState(() => selectedTime = t);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameController.text.trim().isEmpty) return;

                      final deadline = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );

                      if (isEditing) {
                        setState(() {
                          todoToEdit.name = nameController.text.trim();
                          todoToEdit.deadline = deadline;
                        });
                      } else {
                        setState(() {
                          _todos.add(
                            TodoModel(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              name: nameController.text.trim(),
                              deadline: deadline,
                            ),
                          );
                        });
                      }
                      // Simpan perubahan ke penyimpanan lokal
                      _saveTasks();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isEditing ? 'Simpan Perubahan' : 'Buat Tugas',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _deleteTodo(String id) {
    setState(() {
      _todos.removeWhere((t) => t.id == id);
    });
    // Simpan perubahan setelah penghapusan
    _saveTasks();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tugas dihapus'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // --- TAMPILAN UTAMA (UI) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text(
              'Live Task',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: _buildDrawer(),
      body: _todos.isEmpty
          ? _buildEmptyState()
          : StreamBuilder<DateTime>(
              stream: _timeStream,
              builder: (context, snapshot) {
                final sortedTodos = List<TodoModel>.from(_todos)
                  ..sort((a, b) {
                    if (a.isCompleted != b.isCompleted) {
                      return a.isCompleted ? 1 : -1;
                    }
                    return a.deadline.compareTo(b.deadline);
                  });

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: sortedTodos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _buildTodoCard(sortedTodos[index]),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskDialog(),
        elevation: 4,
        icon: const Icon(Icons.add),
        label: const Text('Baru'),
      ),
    );
  }

  Widget _buildTodoCard(TodoModel todo) {
    final isExpired = todo.isExpired();

    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: Colors.red.shade700),
      ),
      confirmDismiss: (_) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hapus Tugas?'),
            content: Text('"${todo.name}" akan dihapus permanen.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => _deleteTodo(todo.id),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: todo.isCompleted
                ? Colors.green.withValues(alpha: 0.3)
                : isExpired
                    ? Colors.red.withValues(alpha: 0.3)
                    : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              onTap: () {
                if (isExpired) {
                  _showStatusMessage('Tugas terlambat tidak dapat diedit.');
                } else {
                  _showTaskDialog(todoToEdit: todo);
                }
              },
              leading: isExpired
                  ? const Icon(Icons.warning_amber_rounded, color: Colors.red)
                  : Transform.scale(
                      scale: 1.2,
                      child: Checkbox(
                        value: todo.isCompleted,
                        activeColor: Colors.green,
                        shape: const CircleBorder(),
                        onChanged: (val) {
                          setState(() {
                            todo.isCompleted = val ?? false;
                          });
                          _saveTasks();
                        },
                      ),
                    ),
              title: Text(
                todo.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  decoration:
                      todo.isCompleted ? TextDecoration.lineThrough : null,
                  color: todo.isCompleted ? Colors.grey : Colors.black87,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: isExpired ? Colors.red : Colors.blueGrey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      todo.getCountdownText(),
                      style: TextStyle(
                        color: isExpired ? Colors.red : Colors.blueGrey,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: todo.isCompleted
                  ? const Icon(Icons.check_circle,
                      color: Colors.green, size: 20)
                  : isExpired
                      ? const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 20,
                        )
                      : null,
            ),
            if (!todo.isCompleted)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _buildProgressBar(todo, isExpired),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_add, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Belum ada tugas aktif',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            accountName: const Text(
              "Pengguna Tamu",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: const Text("Versi Testing 1.0"),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Tentang Aplikasi'),
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: 'Live Task',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2025 Dibuat dengan Flutter',
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Cara Penggunaan'),
            onTap: _showHowToUse,
          ),
        ],
      ),
    );
  }
}

class _HowToItem extends StatelessWidget {
  const _HowToItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final accentSoft = accent.withValues(alpha: 0.1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
