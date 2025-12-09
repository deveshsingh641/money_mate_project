import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'dart:math' as math;

import 'firebase_options.dart';
import 'models/transaction.dart';
import 'models/asset.dart';
import 'models/liability.dart';
import 'models/goal.dart';
import 'models/bill.dart';
import 'models/achievement.dart';
import 'models/challenge.dart';
import 'models/shared_wallet.dart';
import 'providers/transaction_manager.dart';
import 'screens/dashboard/dashboard_content.dart';
import 'widgets/primary_card.dart';
import 'widgets/status_chip.dart';

class ThemeManager extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void toggleTheme(bool isDark) {
    setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TransactionManager()),
        ChangeNotifierProvider(create: (context) => ThemeManager()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, _) {
        return MaterialApp(
          title: 'Money-Mate',
          themeMode: themeManager.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00F289),
              primary: const Color(0xFF00F289),
              secondary: const Color(0xFF22D3EE),
              background: const Color(0xFF020617),
              surface: const Color(0xFF020617),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF020617),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF020617),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F289),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                side: const BorderSide(color: Color(0xFF1F2937)),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF1F2937), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF1F2937), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF00F289),
                  width: 1.8,
                ),
              ),
              filled: true,
              fillColor: const Color(0xFF020617),
            ),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: const Color(0xFF020617),
              selectedItemColor: const Color(0xFF00F289),
              unselectedItemColor: Colors.grey.shade500,
              selectedIconTheme: const IconThemeData(size: 26),
              unselectedIconTheme: const IconThemeData(size: 22),
              type: BottomNavigationBarType.fixed,
              elevation: 16,
            ),
            textTheme: const TextTheme(
              headlineSmall: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              titleMedium: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              bodyMedium: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFFE5E7EB),
              ),
              bodySmall: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF14B8A6),
              brightness: Brightness.dark,
            ),
          ),
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData) {
                return const HomeScreen();
              }
              return const LoginPage();
            },
          ),
        );
      },
    );
  }
}

final TransactionManager manager = TransactionManager();

// --- Home Screen (Dashboard) Widget ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _widgetOptions = <Widget>[
    DashboardContent(),
    GoalsPage(),
    BillPage(),
    AchievementsPage(),
    SharedWalletsPage(),
  ];

  final List<String> _appBarTitles = const [
    'Dashboard',
    'My Goals',
    'My Bills',
    'Achievements',
    'Shared Wallets',
  ];

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDashboard = _selectedIndex == 0;
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        user?.displayName ?? user?.email ?? user?.phoneNumber ?? 'Money Mate';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00F289),
              Color(0xFF020617),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom header similar to PhonePe/Paytm
              if (isDashboard)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Good Evening,',
                              style: theme.textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Text(displayName,
                              style: theme.textTheme.headlineSmall),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  theme.colorScheme.primary.withOpacity(0.08),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) =>
                                      const AddTransactionOptionsPage(),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.add,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => const ProfileScreen(),
                                ),
                              );
                            },
                            child: Builder(
                              builder: (context) {
                                final initials = displayName.isNotEmpty
                                    ? displayName
                                        .trim()
                                        .split(' ')
                                        .where((p) => p.isNotEmpty)
                                        .take(2)
                                        .map((p) => p[0].toUpperCase())
                                        .join()
                                    : 'MM';

                                if (user?.photoURL != null) {
                                  return CircleAvatar(
                                    radius: 18,
                                    backgroundImage:
                                        NetworkImage(user!.photoURL!),
                                  );
                                }

                                return CircleAvatar(
                                  radius: 18,
                                  backgroundColor: theme.colorScheme.primary
                                      .withOpacity(0.12),
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _appBarTitles[_selectedIndex],
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox.shrink(),
                    ],
                  ),
                ),

              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: _widgetOptions,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_rounded),
            label: 'Goals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Bills',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_rounded),
            label: 'Achievements',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wallet_rounded),
            label: 'Wallets',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

IconData _billIconForName(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('electric') || lower.contains('power')) {
    return Icons.flash_on_rounded;
  }
  if (lower.contains('rent') ||
      lower.contains('house') ||
      lower.contains('home')) {
    return Icons.home_work_rounded;
  }
  if (lower.contains('sub') ||
      lower.contains('netflix') ||
      lower.contains('prime')) {
    return Icons.subscriptions_rounded;
  }
  if (lower.contains('wifi') || lower.contains('internet')) {
    return Icons.wifi_rounded;
  }
  if (lower.contains('emi') || lower.contains('loan')) {
    return Icons.account_balance_rounded;
  }
  if (lower.contains('phone') || lower.contains('mobile')) {
    return Icons.phone_iphone_rounded;
  }
  return Icons.receipt_long_rounded;
}

void _showAddBillDialog(BuildContext context, TransactionManager manager) {
  final titleController = TextEditingController();
  final amountController = TextEditingController();
  DateTime? selectedDate;
  String repeatCycle = 'Monthly';

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Add bill'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Bill title',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month_rounded),
                    title: Text(
                      selectedDate == null
                          ? 'Pick due date'
                          : DateFormat('dd MMM yyyy').format(selectedDate!),
                    ),
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: now.add(const Duration(days: 3)),
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365 * 3)),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: repeatCycle,
                    decoration: const InputDecoration(
                      labelText: 'Repeat cycle',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'One-time',
                        child: Text('One-time'),
                      ),
                      DropdownMenuItem(
                        value: 'Monthly',
                        child: Text('Monthly'),
                      ),
                      DropdownMenuItem(
                        value: 'Yearly',
                        child: Text('Yearly'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        repeatCycle = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final rawAmount =
                      amountController.text.trim().replaceAll(',', '');
                  final amount = double.tryParse(rawAmount) ?? 0.0;
                  if (title.isEmpty || amount <= 0 || selectedDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please enter a valid title, amount, and due date for the bill.',
                        ),
                      ),
                    );
                    return;
                  }
                  final bill = Bill(
                    id: '',
                    name: title,
                    amount: amount,
                    dueDate: selectedDate!,
                    isPaid: false,
                    repeatCycle: repeatCycle,
                  );
                  await manager.addBillToFirestore(bill);
                  // ignore: use_build_context_synchronously
                  Navigator.of(ctx).pop();
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );
}

IconData _walletIconForName(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('cash')) {
    return Icons.money_rounded;
  }
  if (lower.contains('bank') || lower.contains('account')) {
    return Icons.account_balance_wallet_rounded;
  }
  if (lower.contains('upi') ||
      lower.contains('gpay') ||
      lower.contains('pay')) {
    return Icons.qr_code_scanner_rounded;
  }
  if (lower.contains('card') ||
      lower.contains('credit') ||
      lower.contains('debit')) {
    return Icons.credit_card_rounded;
  }
  return Icons.wallet_rounded;
}

void _showAddWalletDialog(
  BuildContext context,
  TransactionManager manager,
) {
  final nameController = TextEditingController();
  final membersController = TextEditingController();
  final balanceController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Add wallet'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Wallet name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Initial balance (₹)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: membersController,
                decoration: const InputDecoration(
                  labelText: 'Members (comma separated)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final balance =
                  double.tryParse(balanceController.text.trim()) ?? 0.0;
              final members = membersController.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              if (name.isEmpty) {
                Navigator.of(ctx).pop();
                return;
              }
              final wallet = SharedWallet(
                id: '',
                name: name,
                members: members,
                balance: balance,
              );
              await manager.addSharedWalletToFirestore(wallet);
              // ignore: use_build_context_synchronously
              Navigator.of(ctx).pop();
            },
            child: const Text('Create'),
          ),
        ],
      );
    },
  );
}

void _showTransferDialog(
  BuildContext context,
  TransactionManager manager,
  List<SharedWallet> wallets,
  SharedWallet fromWallet,
) {
  SharedWallet? toWallet;
  final amountController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Transfer between wallets'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<SharedWallet>(
                    value: toWallet,
                    decoration: const InputDecoration(
                      labelText: 'To wallet',
                    ),
                    items: wallets
                        .where((w) => w.id != fromWallet.id)
                        .map(
                          (w) => DropdownMenuItem(
                            value: w,
                            child: Text(w.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        toWallet = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final amount =
                      double.tryParse(amountController.text.trim()) ?? 0.0;
                  if (amount <= 0 || toWallet == null) {
                    Navigator.of(ctx).pop();
                    return;
                  }
                  final fromUpdated = SharedWallet(
                    id: fromWallet.id,
                    name: fromWallet.name,
                    members: fromWallet.members,
                    balance: fromWallet.balance - amount,
                  );
                  final toUpdated = SharedWallet(
                    id: toWallet!.id,
                    name: toWallet!.name,
                    members: toWallet!.members,
                    balance: toWallet!.balance + amount,
                  );

                  await manager.updateSharedWalletInFirestore(fromUpdated);
                  await manager.updateSharedWalletInFirestore(toUpdated);
                  // ignore: use_build_context_synchronously
                  Navigator.of(ctx).pop();
                },
                child: const Text('Transfer'),
              ),
            ],
          );
        },
      );
    },
  );
}

// --- Profile Screen ---
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _saving = false;
  bool _sharing = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';
    _photoUrl = user?.photoURL;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _saving = true;
    });

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await user.updatePhotoURL(url);
      setState(() {
        _photoUrl = url;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile photo')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _saving = true;
    });

    try {
      await user.updateDisplayName(_nameController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _shareApp() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _sharing = true;
    });

    try {
      final manager = Provider.of<TransactionManager>(context, listen: false);
      final code = await manager.generateReferralCode(user.uid);

      final message =
          'Check out Money-Mate! It helps you track your money, goals and bills easily.\n'
          'Use my referral code: $code when you sign up.\n'
          'Download: https://play.google.com/store/apps/details?id=com.example.money_mate';

      await Share.share(message, subject: 'Try Money-Mate');
    } finally {
      if (mounted) {
        setState(() {
          _sharing = false;
        });
      }
    }
  }

  void _openImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    final initials = (user?.displayName ?? user?.email ?? 'MM')
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundImage:
                      _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                  child: _photoUrl == null
                      ? Text(
                          initials,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 22,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _openImagePicker,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ProfileTextField(
            controller: _nameController,
            label: 'Full name',
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: 12),
          _ProfileReadOnlyField(
            label: 'Email',
            value: user?.email ?? 'Not set',
            icon: Icons.email_rounded,
          ),
          const SizedBox(height: 12),
          _ProfileReadOnlyField(
            label: 'User ID',
            value: user?.uid ?? '-',
            icon: Icons.key_rounded,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveProfile,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Save changes'),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'More',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.share_rounded,
            title: 'Share / Refer Money-Mate',
            subtitle: 'Invite friends and share your referral code',
            trailing: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right_rounded),
            onTap: _shareApp,
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: 'Sign out',
            subtitle: 'Log out and switch to a different account',
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _ProfileReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      controller: TextEditingController(text: value),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

// --- Settings Screen ---
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _privacyLock = false;
  bool _savingPassword = false;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_newPasswordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() {
      _savingPassword = true;
    });

    try {
      await user.updatePassword(_newPasswordController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully')),
        );
      }
      _currentPasswordController.clear();
      _newPasswordController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update password')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingPassword = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final isDark = themeManager.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Account',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _notificationsEnabled,
            title: const Text('Enable notifications'),
            subtitle: const Text('Get reminders about bills and goals'),
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          SwitchListTile(
            value: _privacyLock,
            title: const Text('Privacy lock'),
            subtitle: const Text('Require authentication when opening app'),
            onChanged: (value) {
              setState(() {
                _privacyLock = value;
              });
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Appearance',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: isDark,
            title: const Text('Dark mode'),
            onChanged: (value) {
              themeManager.toggleTheme(value);
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Security',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current password',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New password',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _savingPassword ? null : _changePassword,
              child: _savingPassword
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Change password'),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _loading = false;
  bool _googleLoading = false;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _navigateWithBiometrics(BuildContext context) async {
    bool allowBiometric = false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (canCheck && isSupported) {
        allowBiometric = await _localAuth.authenticate(
          localizedReason: 'Use biometrics to quickly unlock Money Mate',
          options: const AuthenticationOptions(biometricOnly: true),
        );
      }
    } catch (_) {
      allowBiometric = false;
    }

    if (!mounted) return;

    // Even if biometrics fail or are unavailable, fall back to normal navigation
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (ctx) => const HomeScreen()),
    );
  }

  Future<void> _handleLogin(BuildContext context) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password to continue')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _navigateWithBiometrics(context);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Login failed')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Something went wrong. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    setState(() => _googleLoading = true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // user cancelled the flow
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      await _navigateWithBiometrics(context);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Google sign-in failed')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong with Google sign-in.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF101010),
              Color(0xFF020202),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Neon background glow
            Positioned(
              top: -120,
              left: -40,
              right: -40,
              child: Container(
                height: 260,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.9,
                    colors: [
                      Color(0xFFCCFF00),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Orb + title section
                      Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            radius: 0.6,
                            colors: [
                              Color(0xFFCCFF00),
                              Color(0xFF1A1A1A),
                            ],
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFCCFF00).withOpacity(0.4),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to access your smart money insights.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        width: size.width > 460 ? 460 : double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF050505).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.7),
                              blurRadius: 40,
                              offset: const Offset(0, 22),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Email address*',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _emailController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'example@gmail.com',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF111111),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFCCFF00),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Password*',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: '@Sn123hsn#',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF111111),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(16),
                                  ),
                                  borderSide: BorderSide(
                                    color: Color(0xFFCCFF00),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      activeColor: const Color(0xFFCCFF00),
                                      onChanged: (v) {
                                        setState(() {
                                          _rememberMe = v ?? false;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Remember me',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ForgotPasswordPage(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFCCFF00),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFCCFF00),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                onPressed: _loading
                                    ? null
                                    : () => _handleLogin(context),
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.black,
                                          ),
                                        ),
                                      )
                                    : const Text(
                                        'Sign in',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: const [
                                Expanded(child: Divider(color: Colors.white24)),
                                SizedBox(width: 8),
                                Text(
                                  'Or continue with',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white54,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(child: Divider(color: Colors.white24)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _NeonSocialButton(
                                  label: 'Google',
                                  icon: Icons.g_mobiledata,
                                  onTap: _googleLoading
                                      ? null
                                      : () => _handleGoogleSignIn(context),
                                ),
                                const SizedBox(width: 12),
                                _NeonSocialButton(
                                  label: 'Apple',
                                  icon: Icons.apple,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SignUpPage(),
                            ),
                          );
                        },
                        child: const Text(
                          "Don't have an account? Sign up",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
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

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister(BuildContext context) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password to continue')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Registration failed')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Something went wrong. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF101010),
              Color(0xFF020202),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -40,
              right: -40,
              child: Container(
                height: 260,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.9,
                    colors: [
                      Color(0xFFCCFF00),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            radius: 0.6,
                            colors: [
                              Color(0xFFCCFF00),
                              Color(0xFF1A1A1A),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Create Your Account?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create your account to explore smart money journeys.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: size.width > 460 ? 460 : double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF050505).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.7),
                              blurRadius: 40,
                              offset: const Offset(0, 22),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Full Name*',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Alex Smith',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF111111),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(16)),
                                  borderSide: BorderSide(
                                    color: Color(0xFFCCFF00),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Email address*',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _emailController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'example@gmail.com',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF111111),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(16)),
                                  borderSide: BorderSide(
                                    color: Color(0xFFCCFF00),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Password*',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: '@Sn123hsn#',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF111111),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(16)),
                                  borderSide: BorderSide(
                                    color: Color(0xFFCCFF00),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFCCFF00),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                onPressed: _loading
                                    ? null
                                    : () => _handleRegister(context),
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.black),
                                        ),
                                      )
                                    : const Text(
                                        'Register',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _NeonSocialButton(
                                  label: 'Google',
                                  icon: Icons.g_mobiledata,
                                ),
                                const SizedBox(width: 12),
                                _NeonSocialButton(
                                  label: 'Apple',
                                  icon: Icons.apple,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Already have an account? Sign In',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
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

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail(BuildContext context) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email address')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to send reset email')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Something went wrong. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF101010),
              Color(0xFF020202),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -40,
              right: -40,
              child: Container(
                height: 260,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.9,
                    colors: [
                      Color(0xFFCCFF00),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            radius: 0.6,
                            colors: [
                              Color(0xFFCCFF00),
                              Color(0xFF1A1A1A),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Enter your email and we'll send a reset link.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: size.width > 460 ? 460 : double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF050505).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.7),
                              blurRadius: 40,
                              offset: const Offset(0, 22),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Email address*',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _emailController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'example@gmail.com',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF111111),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(16)),
                                  borderSide: BorderSide(
                                    color: Color(0xFFCCFF00),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFCCFF00),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                onPressed: _loading
                                    ? null
                                    : () => _sendResetEmail(context),
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.black),
                                        ),
                                      )
                                    : const Text(
                                        'Send Code',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Already have an account? Sign In',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
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

class _NeonSocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _NeonSocialButton({
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TransactionManager>(context, listen: false);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Goals'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00F289),
              Color(0xFF020617),
            ],
          ),
        ),
        child: StreamBuilder<List<Goal>>(
          stream: manager.goalsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final goals = snapshot.data ?? [];
            if (goals.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Start by creating your first financial goal – like a laptop, vacation, or emergency fund.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                final progress = goal.targetAmount <= 0
                    ? 0.0
                    : (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
                final remaining = (goal.targetAmount - goal.currentAmount)
                    .clamp(0.0, double.infinity);
                final now = DateTime.now();
                final daysLeft = goal.deadline
                    .difference(DateTime(now.year, now.month, now.day))
                    .inDays;
                final weeksLeft = (daysLeft / 7).clamp(1, 520).toDouble();
                final weeklyRecommendation =
                    remaining > 0 ? remaining / weeksLeft : 0.0;

                final isCompleted = progress >= 0.999;
                final baseOffset = 16 + index * 4.0;

                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: baseOffset, end: 0),
                  duration:
                      Duration(milliseconds: 520 + (index.clamp(0, 6) * 40)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    final opacity = 1 - (value / baseOffset).clamp(0.0, 1.0);
                    return Transform.translate(
                      offset: Offset(0, value),
                      child: Opacity(opacity: opacity, child: child),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: PrimaryCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  goal.name,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              StatusChip(
                                label: goal.priority,
                                color: _priorityColor(goal.priority),
                                icon: goal.priority.toLowerCase() == 'high'
                                    ? Icons.whatshot_rounded
                                    : goal.priority.toLowerCase() == 'low'
                                        ? Icons.spa_rounded
                                        : Icons.flag_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Target: ₹${goal.targetAmount.toStringAsFixed(0)}   •   Saved: ₹${goal.currentAmount.toStringAsFixed(0)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Deadline: ${DateFormat('dd MMM yyyy').format(goal.deadline)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isCompleted
                                    ? const Color(0xFF43A047)
                                    : const Color(0xFF66BB6A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}% complete',
                                style: theme.textTheme.bodySmall,
                              ),
                              if (isCompleted)
                                AnimatedScale(
                                  scale: 1.05,
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutBack,
                                  child: const Text(
                                    'Completed',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF43A047),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (!isCompleted && remaining > 0)
                            Text(
                              'Save about ₹${weeklyRecommendation.toStringAsFixed(0)} weekly to reach this goal on time.',
                              style: theme.textTheme.bodySmall,
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  _showAddMoneyDialog(context, manager, goal);
                                },
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add money'),
                              ),
                              const SizedBox(width: 8),
                              if (isCompleted)
                                TextButton.icon(
                                  onPressed: () {
                                    manager.removeGoalFromFirestore(goal.id);
                                  },
                                  icon: const Icon(Icons.archive_rounded),
                                  label: const Text('Archive'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddGoalDialog(context, manager);
        },
        icon: const Icon(Icons.flag_rounded),
        label: const Text('Add goal'),
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.blueGrey;
      default:
        return Colors.orange;
    }
  }

  void _showAddMoneyDialog(
    BuildContext context,
    TransactionManager manager,
    Goal goal,
  ) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add money to goal'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final value = double.tryParse(controller.text.trim()) ?? 0.0;
                if (value <= 0) {
                  Navigator.of(ctx).pop();
                  return;
                }
                final updated = goal.copyWith(
                  currentAmount: goal.currentAmount + value,
                );
                await manager.updateGoalInFirestore(updated);
                // ignore: use_build_context_synchronously
                Navigator.of(ctx).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showAddGoalDialog(
    BuildContext context,
    TransactionManager manager,
  ) {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    DateTime? selectedDeadline;
    String priority = 'Medium';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Create goal'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Goal title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Target amount (₹)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month_rounded),
                      title: Text(
                        selectedDeadline == null
                            ? 'Pick deadline'
                            : DateFormat('dd MMM yyyy')
                                .format(selectedDeadline!),
                      ),
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: now.add(const Duration(days: 30)),
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365 * 5)),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDeadline = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'High',
                          child: Text('High'),
                        ),
                        DropdownMenuItem(
                          value: 'Medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(
                          value: 'Low',
                          child: Text('Low'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          priority = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final target =
                        double.tryParse(targetController.text.trim()) ?? 0.0;
                    if (name.isEmpty ||
                        target <= 0 ||
                        selectedDeadline == null) {
                      Navigator.of(ctx).pop();
                      return;
                    }
                    final goal = Goal(
                      id: '',
                      name: name,
                      targetAmount: target,
                      currentAmount: 0,
                      deadline: selectedDeadline!,
                      priority: priority,
                    );
                    await manager.addGoalToFirestore(goal);
                    // ignore: use_build_context_synchronously
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class BillPage extends StatelessWidget {
  const BillPage({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TransactionManager>(context, listen: false);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bills'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00F289),
              Color(0xFF020617),
            ],
          ),
        ),
        child: StreamBuilder<List<Bill>>(
          stream: manager.billsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final bills = snapshot.data ?? [];
            if (bills.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Add your first bill – electricity, rent, subscriptions, EMIs and more – and never miss a due date.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            bills.sort((a, b) => a.dueDate.compareTo(b.dueDate));
            final today = DateTime.now();
            final todayDate = DateTime(today.year, today.month, today.day);

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: bills.length,
              itemBuilder: (context, index) {
                final bill = bills[index];
                final dueDate = DateTime(
                    bill.dueDate.year, bill.dueDate.month, bill.dueDate.day);
                final diffDays = dueDate.difference(todayDate).inDays;
                final isOverdue = !bill.isPaid && diffDays < 0;
                final isDueSoon =
                    !bill.isPaid && diffDays >= 0 && diffDays <= 3;

                String statusText;
                Color statusColor;
                IconData statusIcon;
                if (bill.isPaid) {
                  statusText = 'Paid';
                  statusColor = Colors.green;
                  statusIcon = Icons.check_circle_rounded;
                } else if (isOverdue) {
                  statusText = 'Overdue';
                  statusColor = Colors.red;
                  statusIcon = Icons.warning_amber_rounded;
                } else if (isDueSoon) {
                  statusText = 'Due in $diffDays days';
                  statusColor = Colors.orange;
                  statusIcon = Icons.schedule_rounded;
                } else {
                  statusText = 'Upcoming';
                  statusColor = theme.colorScheme.primary;
                  statusIcon = Icons.calendar_today_rounded;
                }

                final baseOffset = 18 + index * 3.0;

                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: baseOffset, end: 0),
                  duration:
                      Duration(milliseconds: 520 + (index.clamp(0, 6) * 35)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    final opacity = 1 - (value / baseOffset).clamp(0.0, 1.0);
                    return Transform.translate(
                      offset: Offset(0, value),
                      child: Opacity(opacity: opacity, child: child),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: PrimaryCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: bill.isPaid
                                ? Colors.green.shade50
                                : Colors.blue.shade50,
                            child: Icon(
                              _billIconForName(bill.name),
                              color: bill.isPaid
                                  ? Colors.green
                                  : theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        bill.name,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ),
                                    StatusChip(
                                      label: statusText,
                                      color: statusColor,
                                      icon: statusIcon,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${bill.amount.toStringAsFixed(0)} • Due ${DateFormat('dd MMM yyyy').format(bill.dueDate)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  bill.repeatCycle,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: AnimatedScale(
                              scale: bill.isPaid ? 1.08 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutBack,
                              child: Icon(
                                bill.isPaid
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked,
                                color: bill.isPaid ? Colors.green : Colors.grey,
                              ),
                            ),
                            onPressed: () {
                              manager.togglePaidStatusInFirestore(
                                  bill.id, !bill.isPaid);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddBillDialog(context, manager);
        },
        icon: const Icon(Icons.receipt_long_rounded),
        label: const Text('Add bill'),
      ),
    );
  }
}

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TransactionManager>(context);
    final theme = Theme.of(context);
    final achievements = manager.achievements;

    final unlockedCount =
        achievements.where((a) => a.isUnlocked).toList().length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00F289),
              Color(0xFF020617),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                unlockedCount == 0
                    ? 'Start tracking your money to unlock your first achievement.'
                    : 'Great job! You have unlocked $unlockedCount achievements.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 4 / 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: achievements.length,
                  itemBuilder: (context, index) {
                    final a = achievements[index];
                    final unlocked = a.isUnlocked;
                    final baseOffset = 18 + index * 4.0;

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: baseOffset, end: 0),
                      duration: Duration(
                          milliseconds: 520 + (index.clamp(0, 6) * 45)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        final opacity =
                            1 - (value / baseOffset).clamp(0.0, 1.0);
                        return Transform.translate(
                          offset: Offset(0, value),
                          child: Opacity(opacity: opacity, child: child),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: unlocked
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF8E24AA),
                                    Color(0xFFBA68C8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFFF3F4F6),
                                    Color(0xFFE5E7EB),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          boxShadow: unlocked
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF8E24AA)
                                        .withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : const [],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: unlocked
                                        ? const Color(0xFFFFC107)
                                            .withOpacity(0.18)
                                        : Colors.white,
                                    child: Icon(
                                      a.icon,
                                      color: unlocked
                                          ? const Color(0xFFFFC107)
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  AnimatedScale(
                                    scale: unlocked ? 1.1 : 1.0,
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutBack,
                                    child: Icon(
                                      unlocked
                                          ? Icons.emoji_events_rounded
                                          : Icons.lock_outline_rounded,
                                      color: unlocked
                                          ? const Color(0xFFFFF8E1)
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                a.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: unlocked
                                      ? Colors.white
                                      : const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                a.description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: unlocked
                                      ? Colors.white.withOpacity(0.9)
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const Spacer(),
                              if (!unlocked)
                                Text(
                                  'Keep going to unlock this badge!',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SharedWalletsPage extends StatelessWidget {
  const SharedWalletsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<TransactionManager>(context, listen: false);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00F289),
              Color(0xFF020617),
            ],
          ),
        ),
        child: StreamBuilder<List<SharedWallet>>(
          stream: manager.sharedWalletsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final wallets = snapshot.data ?? [];
            if (wallets.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Create wallets for Cash, Bank, UPI, or Credit Card to track balances separately.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final totalBalance = wallets.fold<double>(
              0.0,
              (sum, w) => sum + w.balance,
            );

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: wallets.length,
              itemBuilder: (context, index) {
                final w = wallets[index];
                final share = totalBalance <= 0
                    ? 0.0
                    : (w.balance / totalBalance).clamp(0.0, 1.0);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: PrimaryCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              const Color(0xFF3949AB).withOpacity(0.08),
                          child: Icon(
                            _walletIconForName(w.name),
                            color: const Color(0xFF3949AB),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      w.name,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ),
                                  Text(
                                    '₹${w.balance.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${w.members.length} member${w.members.length == 1 ? '' : 's'}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: share,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF3949AB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'transfer') {
                              _showTransferDialog(context, manager, wallets, w);
                            } else if (value == 'delete') {
                              manager.removeSharedWalletFromFirestore(w.id);
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(
                              value: 'transfer',
                              child: Text('Transfer'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddWalletDialog(context, manager);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add wallet'),
      ),
    );
  }
}

class AddTransactionOptionsPage extends StatelessWidget {
  const AddTransactionOptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const AddTransactionPage(
                      initialType: TransactionType.income,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_downward_rounded),
              label: const Text('Add Income'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const AddTransactionPage(
                      initialType: TransactionType.expense,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_upward_rounded),
              label: const Text('Add Expense'),
            ),
          ],
        ),
      ),
    );
  }
}

class AddTransactionPage extends StatefulWidget {
  final TransactionType initialType;

  const AddTransactionPage({super.key, required this.initialType});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  late ExpenseCategory _selectedCategory;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = ExpenseCategory.values.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    final manager = Provider.of<TransactionManager>(context, listen: false);

    final rawAmount = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(rawAmount) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await manager.addTransactionRaw(
        amount: amount,
        category: _selectedCategory.name,
        type: widget.initialType.name,
        date: _selectedDate,
        description: _descriptionController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = widget.initialType == TransactionType.income;
    return Scaffold(
      appBar: AppBar(
        title: Text(isIncome ? 'Add Income' : 'Add Expense'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExpenseCategory>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
              ),
              items: ExpenseCategory.values
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_rounded),
              title: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
