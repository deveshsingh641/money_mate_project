import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ChangeNotifierProvider(
      create: (context) => TransactionManager(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Money-Mate',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
        ),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

// --- Data Models and Manager ---

enum TransactionType { income, expense }
enum ExpenseCategory { food, transport, bills, entertainment, salary, gift, other }

extension ExpenseCategoryExtension on ExpenseCategory {
  String get emoji {
    switch (this) {
      case ExpenseCategory.food:
        return '🍔';
      case ExpenseCategory.transport:
        return '🚗';
      case ExpenseCategory.bills:
        return '🧾';
      case ExpenseCategory.entertainment:
        return '🎬';
      case ExpenseCategory.salary:
        return '💼';
      case ExpenseCategory.gift:
        return '🎁';
      case ExpenseCategory.other:
        return '💰';
      default:
        return '❓';
    }
  }

  String get displayName {
    switch (this) {
      case ExpenseCategory.food:
        return 'Food';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.bills:
        return 'Bills';
      case ExpenseCategory.entertainment:
        return 'Entertainment';
      case ExpenseCategory.salary:
        return 'Salary';
      case ExpenseCategory.gift:
        return 'Gift';
      case ExpenseCategory.other:
        return 'Other';
      default:
        return 'Unknown';
    }
  }
}

enum AssetType { savings, investment, property }
enum LiabilityType { mortgage, loan, creditCard }

class Transaction {
  final String id;
  final double amount;
  final ExpenseCategory category;
  final TransactionType type;
  final DateTime date;
  final String description;

  Transaction({
    required this.id,
    required this.amount,
    required this.category,
    required this.type,
    required this.date,
    required this.description,
  });
}

Transaction transactionFromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return Transaction(
    id: doc.id,
    amount: (data['amount'] as num).toDouble(),
    category: ExpenseCategory.values.byName(data['category'] as String),
    type: TransactionType.values.byName(data['type'] as String),
    date: (data['date'] as Timestamp).toDate(),
    description: data['description'] as String,
  );
}

class Asset {
  final String name;
  final double value;
  final AssetType type;
  Asset({required this.name, required this.value, required this.type});
}

class Liability {
  final String name;
  final double amount;
  final LiabilityType type;
  Liability({required this.name, required this.amount, required this.type});
}

class Goal {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime deadline;

  Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
  });
}

class Bill {
  final String id;
  final String name;
  final double amount;
  final DateTime dueDate;
  final bool isPaid;

  Bill({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
  });
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool isUnlocked;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isUnlocked = false,
  });
}

class Challenge {
  final String title;
  final String description;
  final double progress;
  final double target;

  Challenge({
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
  });
}

class SharedWallet {
  final String id;
  final String name;
  final List<String> members;
  final double balance;

  SharedWallet({
    required this.id,
    required this.name,
    required this.members,
    required this.balance,
  });
}

class TransactionManager extends ChangeNotifier {
  final CollectionReference _transactionsCollection =
  FirebaseFirestore.instance.collection('transactions');
  final CollectionReference _goalsCollection =
  FirebaseFirestore.instance.collection('goals');
  final CollectionReference _billsCollection =
  FirebaseFirestore.instance.collection('bills');

  Stream<List<Transaction>> get transactionsStream {
    return _transactionsCollection.orderBy('date', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(transactionFromFirestore).toList(),
    );
  }

  Future<void> addTransaction(Transaction transaction) {
    return _transactionsCollection.add({
      'amount': transaction.amount,
      'category': transaction.category.name,
      'type': transaction.type.name,
      'date': transaction.date,
      'description': transaction.description,
    });
  }

  Future<double> get totalBalance async {
    final transactions = await transactionsStream.first;
    final income = transactions.where((t) => t.type == TransactionType.income).fold<double>(0.0, (sum, item) => sum + item.amount);
    final expense = transactions.where((t) => t.type == TransactionType.expense).fold<double>(0.0, (sum, item) => sum + item.amount);
    return income - expense;
  }

  Future<double> get monthlyExpense async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final transactions = await transactionsStream.first;
    return transactions
        .where((t) => t.type == TransactionType.expense)
        .where((t) => t.date.isAfter(startOfMonth) || t.date.isAtSameMomentAs(startOfMonth))
        .fold<double>(0.0, (sum, item) => sum + item.amount);
  }

  Future<double> get previousMonthlyExpense async {
    return 8000.0;
  }

  Future<Map<ExpenseCategory, double>> get expensesByCategory async {
    final transactions = await transactionsStream.first;
    final expenseTransactions = transactions.where((t) => t.type == TransactionType.expense);
    final categoryMap = <ExpenseCategory, double>{};
    for (var category in ExpenseCategory.values) {
      if (category != ExpenseCategory.salary && category != ExpenseCategory.gift) {
        final total = expenseTransactions
            .where((t) => t.category == category)
            .fold<double>(0.0, (sum, item) => sum + item.amount);
        if (total > 0) {
          categoryMap[category] = total;
        }
      }
    }
    return categoryMap;
  }

  final List<Asset> _assets = [
    Asset(name: 'Savings Account', value: 50000.00, type: AssetType.savings),
    Asset(name: 'Stocks Portfolio', value: 80000.00, type: AssetType.investment),
  ];
  final List<Liability> _liabilities = [
    Liability(name: 'Credit Card Debt', amount: 9500.00, type: LiabilityType.creditCard),
    Liability(name: 'Car Loan', amount: 35000.00, type: LiabilityType.loan),
  ];
  double get totalAssets => _assets.fold(0.0, (sum, item) => sum + item.value);
  double get totalLiabilities => _liabilities.fold(0.0, (sum, item) => sum + item.amount);
  double get netWorth => totalAssets - totalLiabilities;
  List<double> get historicalNetWorth => [45000, 48000, 47500, 52000, 55000, 58500];
  Future<List<double>> get historicalMonthlyExpense async {
    final monthlyExpenseValue = await monthlyExpense;
    return [8500, 9200, 7800, 10500, 9800, monthlyExpenseValue];
  }

  String get predictiveInsight => 'You are doing great! Your spending is well within budget. Keep it up!';

  final List<Goal> _goals = [
    Goal(id: '1', name: 'Vacation Fund', targetAmount: 50000, currentAmount: 15000, deadline: DateTime(2026, 6, 30)),
    Goal(id: '2', name: 'New Laptop', targetAmount: 80000, currentAmount: 5000, deadline: DateTime(2026, 12, 31)),
  ];
  final List<Bill> _bills = [
    Bill(id: '1', name: 'Electricity', amount: 1250, dueDate: DateTime(2025, 10, 5)),
    Bill(id: '2', name: 'Internet', amount: 999, dueDate: DateTime(2025, 10, 15)),
    Bill(id: '3', name: 'Credit Card', amount: 5000, dueDate: DateTime(2025, 10, 25)),
  ];

  final List<Achievement> _achievements = [
    Achievement(id: 'a1', title: 'First Steps', description: 'Log your first transaction', icon: Icons.rocket_launch_rounded, isUnlocked: true),
    Achievement(id: 'a2', title: 'Budget Master', description: 'Stay within budget for 30 days', icon: Icons.military_tech_rounded, isUnlocked: false),
    Achievement(id: 'a3', title: 'Power Saver', description: 'Save ₹50,000 for a goal', icon: Icons.savings_rounded, isUnlocked: false),
  ];

  final List<Challenge> _challenges = [
    Challenge(title: 'No-Spend Day', description: 'Avoid any expenses today', progress: 0.5, target: 1.0),
    Challenge(title: 'Reduce Food Spending', description: 'Cut food expenses by 10% this week', progress: 0.7, target: 1.0),
  ];

  final List<SharedWallet> _sharedWallets = [
    SharedWallet(id: 's1', name: 'Trip to Goa', members: ['You', 'Alex', 'Sarah'], balance: -2500.0),
    SharedWallet(id: 's2', name: 'Apartment Rent', members: ['You', 'Jamie'], balance: 1000.0),
  ];

  List<Goal> get goals => _goals;
  List<Bill> get bills => _bills;
  List<Achievement> get achievements => _achievements;
  List<Challenge> get challenges => _challenges;
  List<SharedWallet> get sharedWallets => _sharedWallets;

  void addGoal(Goal newGoal) {
    _goals.add(newGoal);
    notifyListeners();
  }

  void togglePaidStatus(int index) {
    _bills[index] = Bill(
      id: _bills[index].id,
      name: _bills[index].name,
      amount: _bills[index].amount,
      dueDate: _bills[index].dueDate,
      isPaid: !_bills[index].isPaid,
    );
    notifyListeners();
  }

  Future<void> togglePaidStatusInFirestore(String billId, bool isPaid) {
    return _billsCollection.doc(billId).update({
      'isPaid': isPaid,
    });
  }

  Future<double> convertCurrency(double amount, String from, String to) async {
    if (from == 'USD' && to == 'INR') {
      return amount * 82.5;
    }
    return amount;
  }

  Map<String, double> splitBill(double totalAmount, List<String> members) {
    final splitAmount = totalAmount / members.length;
    final Map<String, double> owedAmounts = {};
    for (var member in members) {
      owedAmounts[member] = splitAmount;
    }
    return owedAmounts;
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

  final List<Widget> _widgetOptions = <Widget>[
    const DashboardContent(),
    const GoalsPage(),
    const BillPage(),
    const AchievementsPage(),
    const SharedWalletsPage(),
  ];

  final List<String> _appBarTitles = const [
    'Dashboard',
    'My Goals',
    'My Bills',
    'Achievements',
    'Shared Wallets',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitles[_selectedIndex]),
        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AddTransactionOptionsPage()),
                );
              },
            ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
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
        selectedItemColor: Colors.teal.shade700,
        unselectedItemColor: Colors.grey.shade600,
        backgroundColor: Colors.white,
        elevation: 10,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

// --- Dashboard Content (Refactored) ---
class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildLineChart() {
    return FutureBuilder<List<double>>(
      future: manager.historicalMonthlyExpense,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading chart: ${snapshot.error}'));
        }
        final historicalExpenses = snapshot.data!;
        final maxY = historicalExpenses.reduce((a, b) => a > b ? a : b) * 1.1;
        final minY = historicalExpenses.reduce((a, b) => a < b ? a : b) * 0.9;
        final spots = historicalExpenses.asMap().entries.map((entry) => FlSpot(entry.key.toDouble(), entry.value / 1000.0)).toList();
        return Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
            child: LineChart(
              LineChartData(
                minY: minY / 1000.0,
                maxY: maxY / 1000.0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade300,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final monthIndex = value.toInt();
                        const monthNames = ['Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                        final text = (monthIndex >= 0 && monthIndex < monthNames.length) ? monthNames[monthIndex] : '';
                        const style = TextStyle(color: Colors.grey, fontSize: 12);
                        return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(text, style: style));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 5,
                      getTitlesWidget: (value, meta) => Text("₹${value.toInt()}K", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.teal.shade500,
                    gradient: LinearGradient(colors: [Colors.teal.shade300!.withOpacity(0.5), Colors.white.withOpacity(0.0)]),
                    barWidth: 4,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade100!.withAlpha(128), Colors.white.withAlpha(0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpenseBarChart(BuildContext context, List<Transaction> transactions) {
    final expenses = <ExpenseCategory, double>{};
    transactions.where((t) => t.type == TransactionType.expense).forEach((t) {
      expenses.update(t.category, (value) => value + t.amount, ifAbsent: () => t.amount);
    });

    const List<Color> barColors = [
      Color(0xFF1ABC9C),
      Color(0xFF3498DB),
      Color(0xFFF1C40F),
      Color(0xFFE74C3C),
      Color(0xFF9B59B6),
      Color(0xFF34495E),
    ];
    int colorIndex = 0;
    final List<BarChartGroupData> barGroups = expenses.entries.map((entry) {
      final category = entry.key;
      final amount = entry.value;
      final color = barColors[colorIndex++ % barColors.length];
      return BarChartGroupData(
        x: category.index,
        barRods: [
          BarChartRodData(
            toY: amount,
            color: color,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        showingTooltipIndicators: const [],
      );
    }).toList();
    if (barGroups.isEmpty) {
      return Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(
            child: Text(
              'No expenses to show this month.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.only(top: 20, left: 10, right: 20, bottom: 10),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final category = ExpenseCategory.values[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              category.name,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => Text(
                          '₹${(value / 1000).toStringAsFixed(0)}k',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        interval: 1000,
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1000,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade300,
                      strokeWidth: 1,
                    ),
                  ),
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(
                    enabled: false,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Monthly Spending by Category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetWorthTrendChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          height: 150,
          child: LineChart(
            LineChartData(
              minY: 45000 / 1000.0,
              maxY: 60000 / 1000.0,
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(
                show: true,
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    const FlSpot(0, 45000 / 1000.0),
                    const FlSpot(1, 48000 / 1000.0),
                    const FlSpot(2, 47500 / 1000.0),
                    const FlSpot(3, 52000 / 1000.0),
                    const FlSpot(4, 55000 / 1000.0),
                    const FlSpot(5, 58500 / 1000.0),
                  ],
                  isCurved: true,
                  color: Colors.green.shade500,
                  barWidth: 3,
                  belowBarData: BarAreaData(show: false),
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(double balance) {
    Color balanceColor = balance >= 0 ? Colors.white : Colors.red.shade100;
    Color cardColor = balance >= 0 ? Colors.teal.shade800! : Colors.red.shade800!;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
        gradient: LinearGradient(
          colors: [cardColor, balance >= 0 ? Colors.teal.shade600! : Colors.red.shade600!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Card(
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            children: [
              Text(
                'Total Balance',
                style: TextStyle(fontSize: 18, color: balanceColor, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                NumberFormat.currency(symbol: '₹').format(balance.abs()),
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: balanceColor),
              ),
              if (balance < 0)
                Text(
                  '(Outstanding)',
                  style: TextStyle(fontSize: 14, color: balanceColor.withOpacity(0.8), fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetWorthTracker(BuildContext context) {
    final netWorth = manager.netWorth;
    final assets = manager.totalAssets;
    final liabilities = manager.totalLiabilities;
    Color netWorthColor = netWorth >= 0 ? Colors.green.shade700! : Colors.red.shade700!;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Net Worth:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                Text(
                  NumberFormat.currency(symbol: '₹').format(netWorth),
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: netWorthColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildNetWorthDetail('Total Assets', assets, Colors.green),
            _buildNetWorthDetail('Total Liabilities', liabilities, Colors.red),
            const Divider(height: 16),
            const Text('Net Worth Trend (6 Months)', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
            _buildNetWorthTrendChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildNetWorthDetail(String title, double amount, MaterialColor color) {
    final detailColor = color.shade700;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: detailColor, fontWeight: FontWeight.w500)),
          Text(
            '₹${NumberFormat.currency(symbol: '₹').format(amount)}',
            style: TextStyle(fontWeight: FontWeight.w700, color: detailColor, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingTrends(BuildContext context, double monthlyExpense) {
    const previousMonthlyExpense = 8000.0;
    final difference = monthlyExpense - previousMonthlyExpense;
    final prediction = manager.predictiveInsight;
    bool isPositivePrediction = prediction.toLowerCase().contains('excellent') || prediction.toLowerCase().contains('good');
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Expense vs. Previous Month:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
                Row(
                  children: [
                    Text(
                      NumberFormat.currency(symbol: '₹').format(difference.abs()),
                      style: TextStyle(
                        color: difference < 0 ? Colors.green.shade600 : Colors.red.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Icon(
                      difference < 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: difference < 0 ? Colors.green.shade600 : Colors.red.shade600,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            const Text('Predictive Insight:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPositivePrediction ? Colors.teal.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                prediction,
                style: TextStyle(fontSize: 14, color: isPositivePrediction ? Colors.teal.shade700 : Colors.red.shade700, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetSummary() {
    double transportSpent = 8500.0;
    double transportBudget = 15000.0;
    double foodSpent = 2100.0;
    double foodBudget = 3000.0;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBudgetBar('Transport', transportSpent, transportBudget),
            const SizedBox(height: 16),
            _buildBudgetBar('Food', foodSpent, foodBudget),
            const SizedBox(height: 16),
            Text(
              'Alert: Transport is ${((transportSpent / transportBudget) * 100).toStringAsFixed(0)}% used. Be mindful!',
              style: TextStyle(color: transportSpent / transportBudget > 0.8 ? Colors.red.shade600 : Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetBar(String category, double spent, double limit) {
    double progress = spent / limit;
    Color barColor = progress > 0.8 ? Colors.deepOrange.shade600! : Colors.teal.shade500!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            Text('${NumberFormat.currency(symbol: '₹').format(spent)} / ${NumberFormat.currency(symbol: '₹').format(limit)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return const Center(child: Text('No transactions recorded yet.'));
    }
    transactions.sort((a, b) => b.date.compareTo(a.date));
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final isIncome = transaction.type == TransactionType.income;
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
              child: Text(
                transaction.category.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            title: Text(
              transaction.description,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${transaction.category.displayName} - ${DateFormat('MMM d, yyyy').format(transaction.date)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: Text(
              '${isIncome ? '+' : '-'} ${NumberFormat.currency(symbol: '₹').format(transaction.amount)}',
              style: TextStyle(
                color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinancialAdvice() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.red.shade800),
                const SizedBox(width: 8),
                Text('Financial Warning!', style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.red.shade800,
                )),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Your balance is negative. Here are a few tips to help you get back on track:',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text('• Create a detailed budget.', style: TextStyle(fontSize: 13)),
            const Text('• Identify and reduce non-essential spending.', style: TextStyle(fontSize: 13)),
            const Text('• Prioritize high-interest debt repayment.', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChallengeCard(BuildContext context) {
    final challenge = manager.challenges.first;
    final progressPercentage = (challenge.progress / challenge.target).clamp(0.0, 1.0);
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Challenge',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                ),
                Icon(Icons.emoji_events, color: Colors.teal.shade700),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              challenge.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              challenge.description,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressPercentage,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600!),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progressPercentage * 100).toStringAsFixed(0)}% Complete',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            FutureBuilder<double>(
              future: manager.totalBalance,
              builder: (context, balanceSnapshot) {
                final balance = balanceSnapshot.data ?? 0.0;
                return Column(
                  children: [
                    _buildBalanceCard(balance),
                    if (balance < 0) ...[
                      const SizedBox(height: 16),
                      _buildFinancialAdvice(),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _buildWeeklyChallengeCard(context),
            _buildSectionTitle('Monthly Spending Breakdown'),
            StreamBuilder<List<Transaction>>(
              stream: manager.transactionsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading chart: ${snapshot.error}'));
                }
                final transactions = snapshot.data ?? [];
                return _buildExpenseBarChart(context, transactions);
              },
            ),
            _buildSectionTitle('Spending Trends & Insights'),
            FutureBuilder<double>(
              future: manager.monthlyExpense,
              builder: (context, monthlyExpenseSnapshot) {
                final monthlyExpense = monthlyExpenseSnapshot.data ?? 0.0;
                return _buildSpendingTrends(context, monthlyExpense);
              },
            ),
            const SizedBox(height: 12),
            _buildSectionTitle('Monthly Spending Trend'),
            SizedBox(height: 250, child: _buildLineChart()),
            _buildSectionTitle('Monthly Budget Overview'),
            _buildBudgetSummary(),
            _buildSectionTitle('Net Worth Tracker'),
            _buildNetWorthTracker(context),
            _buildSectionTitle('Recent Transactions'),
            StreamBuilder<List<Transaction>>(
              stream: manager.transactionsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading transactions: ${snapshot.error}'));
                }
                final transactions = snapshot.data ?? [];
                return _buildTransactionList(transactions);
              },
            ),
            const SizedBox(height: 48),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade100),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Goals Page ---
class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionManager>(
      builder: (context, manager, child) {
        if (manager.goals.isEmpty) {
          return const Center(child: Text('No goals set yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: manager.goals.length,
          itemBuilder: (context, index) {
            final goal = manager.goals[index];
            final progress = goal.currentAmount / goal.targetAmount;
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade300,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                        minHeight: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Saved: ₹${goal.currentAmount.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Target: ₹${goal.targetAmount.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Deadline: ${DateFormat('MMM d, yyyy').format(goal.deadline)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- Bill Page ---
class BillPage extends StatelessWidget {
  const BillPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionManager>(
      builder: (context, manager, child) {
        if (manager.bills.isEmpty) {
          return const Center(child: Text('No bills to track.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: manager.bills.length,
          itemBuilder: (context, index) {
            final bill = manager.bills[index];
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: bill.isPaid ? Colors.green.shade50 : Colors.red.shade50,
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: bill.isPaid ? Colors.green.shade200 : Colors.red.shade200,
                  child: Icon(
                    bill.isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                    color: bill.isPaid ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
                title: Text(bill.name, style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                  decoration: bill.isPaid ? TextDecoration.lineThrough : null,
                )),
                subtitle: Text(
                  bill.isPaid ? 'Paid' : 'Due: ${DateFormat('MMM d, yyyy').format(bill.dueDate)}',
                  style: TextStyle(
                    color: bill.isPaid ? Colors.green.shade600 : Colors.red.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Text(
                  '₹${bill.amount}',
                  style: TextStyle(
                    color: bill.isPaid ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  manager.togglePaidStatus(index);
                },
              ),
            );
          },
        );
      },
    );
  }
}

// New: Shared Wallets Page
class SharedWalletsPage extends StatelessWidget {
  const SharedWalletsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionManager>(
      builder: (context, manager, child) {
        final wallets = manager.sharedWallets;
        if (wallets.isEmpty) {
          return const Center(child: Text('No shared wallets yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: wallets.length,
          itemBuilder: (context, index) {
            final wallet = wallets[index];
            final isPositive = wallet.balance >= 0;
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: Icon(
                  Icons.group,
                  color: isPositive ? Colors.green.shade800 : Colors.red.shade800,
                ),
                title: Text(
                  wallet.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Text('Members: ${wallet.members.join(', ')}'),
                trailing: Text(
                  '₹${wallet.balance.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- Achievements Page ---
class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionManager>(
      builder: (context, manager, child) {
        final achievements = manager.achievements;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 0.8,
            ),
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              final achievement = achievements[index];
              return Opacity(
                opacity: achievement.isUnlocked ? 1.0 : 0.4,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          achievement.icon,
                          size: 60,
                          color: achievement.isUnlocked ? Colors.teal.shade700 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          achievement.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: achievement.isUnlocked ? Colors.black87 : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          achievement.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: achievement.isUnlocked ? Colors.black54 : Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// New: Add Transaction Options Page
class AddTransactionOptionsPage extends StatelessWidget {
  const AddTransactionOptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddTransactionPage()));
              },
              icon: const Icon(Icons.edit_note),
              label: const Text('Manual Entry'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ReceiptScanPage()));
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text('Scan Receipt'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SplitBillPage()));
              },
              icon: const Icon(Icons.group),
              label: const Text('Split Expense'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// New page for Receipt Scanning (Placeholder)
class ReceiptScanPage extends StatelessWidget {
  const ReceiptScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_rounded, size: 100, color: Colors.teal),
            const SizedBox(height: 20),
            const Text(
              'Align the receipt within the frame to scan.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Simulating receipt scan...')),
                );
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.document_scanner),
              label: const Text('Start Scan'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// New page for Split Bill
class SplitBillPage extends StatefulWidget {
  const SplitBillPage({super.key});

  @override
  State<SplitBillPage> createState() => _SplitBillPageState();
}

class _SplitBillPageState extends State<SplitBillPage> {
  final _billAmountController = TextEditingController();
  final List<String> _members = ['You'];
  final _newMemberController = TextEditingController();

  void _addMember() {
    if (_newMemberController.text.isNotEmpty) {
      setState(() {
        _members.add(_newMemberController.text);
        _newMemberController.clear();
      });
    }
  }

  void _splitBill() {
    if (_billAmountController.text.isEmpty || _members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a bill amount and at least one member.')),
      );
      return;
    }
    final totalAmount = double.tryParse(_billAmountController.text) ?? 0.0;
    final amountsOwed = manager.splitBill(totalAmount, _members);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bill Split Results'),
        content: SingleChildScrollView(
          child: Column(
            children: amountsOwed.entries.map((entry) =>
                ListTile(
                  title: Text(entry.key),
                  trailing: Text('₹${entry.value.toStringAsFixed(2)}'),
                )
            ).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Expense'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _billAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Bill Amount',
                prefixIcon: Icon(Icons.money),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Members',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: _members.map((member) => Chip(
                label: Text(member),
                onDeleted: () {
                  setState(() {
                    _members.remove(member);
                  });
                },
              )).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newMemberController,
              decoration: InputDecoration(
                labelText: 'Add Member',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addMember,
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _addMember(),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _splitBill,
              icon: const Icon(Icons.calculate),
              label: const Text('Split Bill'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.teal.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// --- Add Transaction Page ---
class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  ExpenseCategory _category = ExpenseCategory.food;
  DateTime _selectedDate = DateTime.now();

  final List<ExpenseCategory> expenseCategories = const [
    ExpenseCategory.food, ExpenseCategory.transport, ExpenseCategory.bills, ExpenseCategory.entertainment, ExpenseCategory.other
  ];
  final List<ExpenseCategory> incomeCategories = const [
    ExpenseCategory.salary, ExpenseCategory.gift, ExpenseCategory.other
  ];

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (!mounted) return;
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveTransaction() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }
    final newTransaction = Transaction(
      id: '',
      amount: double.parse(_amountController.text),
      category: _category,
      type: _type,
      date: _selectedDate,
      description: _descriptionController.text,
    );
    await manager.addTransaction(newTransaction);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_type.name.toUpperCase()} added: ${NumberFormat.currency(symbol: '₹').format(newTransaction.amount)}')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add ${_type.name == 'income' ? 'Income' : 'Expense'}'),
        backgroundColor: _type == TransactionType.income ? Colors.green.shade700 : Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Expense'),
                    selected: _type == TransactionType.expense,
                    onSelected: (selected) {
                      setState(() {
                        _type = TransactionType.expense;
                        _category = expenseCategories.first;
                      });
                    },
                    selectedColor: Colors.red.shade100,
                  ),
                  const SizedBox(width: 16),
                  ChoiceChip(
                    label: const Text('Income'),
                    selected: _type == TransactionType.income,
                    onSelected: (selected) {
                      setState(() {
                        _type = TransactionType.income;
                        _category = incomeCategories.first;
                      });
                    },
                    selectedColor: Colors.green.shade100,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty || double.tryParse(value) == null) {
                    return 'Please enter a valid amount.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ExpenseCategory>(
                value: _category,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: (_type == TransactionType.expense ? expenseCategories : incomeCategories)
                    .map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat.name.toUpperCase()),
                ))
                    .toList(),
                onChanged: (ExpenseCategory? newValue) {
                  setState(() {
                    if (newValue != null) {
                      _category = newValue;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date'),
                subtitle: Text(DateFormat('EEEE, MMM d, yyyy').format(_selectedDate)),
                onTap: () => _selectDate(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade400!),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saveTransaction,
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: Text(
                    'Save ${_type.name}',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _type == TransactionType.income ? Colors.green.shade700 : Colors.red.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Login Page Widget (Improved UI) ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isUserSignedIn = true;

  @override
  void initState() {
    super.initState();
    if (_isUserSignedIn) {
      _signInWithBiometrics();
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  Future<void> _signInWithBiometrics() async {
    final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
    if (!mounted) return;

    if (canAuthenticateWithBiometrics) {
      try {
        final bool didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Sign in to Money-Mate',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
        if (!mounted) return;

        if (didAuthenticate) {
          debugPrint("Biometric authentication successful. Navigating to Home.");
          _navigateToHome();
        } else {
          debugPrint("Biometric authentication failed or cancelled.");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric authentication failed or cancelled.')),
          );
        }
      } catch (e) {
        debugPrint("Error during biometric authentication: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    } else {
      debugPrint("Biometrics not available on this device.");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric login is not available.')),
      );
    }
  }

  void _handleGoogleSignIn() {
    debugPrint("Google Sign-In Attempted: Placeholder.");
    _isUserSignedIn = true;
    _navigateToHome();
  }

  void _handleFacebookSignIn() {
    debugPrint("Facebook Sign-In Attempted: Placeholder.");
    _isUserSignedIn = true;
    _navigateToHome();
  }

  void _handlePhoneSignIn() {
    debugPrint("Phone Sign-In Attempted (Placeholder). Navigating to Home.");
    _isUserSignedIn = true;
    _navigateToHome();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.account_balance_wallet,
                size: 80,
                color: Colors.teal,
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome to Money-Mate',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const Text(
                'Your personal finance manager',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              _buildSignInButton(
                onPressed: _handleGoogleSignIn,
                icon: FontAwesomeIcons.google,
                label: 'Sign in with Google',
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              _buildSignInButton(
                onPressed: _handleFacebookSignIn,
                icon: Icons.facebook,
                label: 'Sign in with Facebook',
                color: Colors.blue.shade800,
              ),
              const SizedBox(height: 16),
              _buildSignInButton(
                onPressed: _handlePhoneSignIn,
                icon: Icons.phone,
                label: 'Sign in with Phone Number',
                color: Colors.teal.shade700!,
              ),
              const SizedBox(height: 48),
              TextButton.icon(
                onPressed: _signInWithBiometrics,
                icon: const Icon(Icons.fingerprint, size: 28, color: Colors.teal),
                label: const Text('Use Biometric Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton({required VoidCallback onPressed, required IconData icon, required String label, required Color color}) {
    final buttonIcon = label == 'Sign in with Google'
        ? FaIcon(icon, color: Colors.white, size: 24.0)
        : Icon(icon, color: Colors.white);

    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: buttonIcon,
        label: Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 5,
        ),
      ),
    );
  }
}




