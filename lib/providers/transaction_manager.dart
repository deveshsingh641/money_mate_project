import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'dart:math';

import '../models/transaction.dart';
import '../models/goal.dart';
import '../models/bill.dart';
import '../models/achievement.dart';
import '../models/challenge.dart';
import '../models/shared_wallet.dart';
import '../models/asset.dart';
import '../models/liability.dart';

class TransactionManager extends ChangeNotifier {
  final CollectionReference _transactionsCollection =
      FirebaseFirestore.instance.collection('transactions');
  final CollectionReference _goalsCollection =
      FirebaseFirestore.instance.collection('goals');
  final CollectionReference _billsCollection =
      FirebaseFirestore.instance.collection('bills');
  final CollectionReference _sharedWalletsCollection =
      FirebaseFirestore.instance.collection('shared_wallets');
  final CollectionReference _achievementsCollection =
      FirebaseFirestore.instance.collection('achievements');
  final CollectionReference _challengesCollection =
      FirebaseFirestore.instance.collection('challenges');
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  TransactionManager() {
    _listenToAchievements();
    _listenToChallenges();
  }

  // --- Transactions Stream (Dynamic) ---
  Stream<List<Transaction>> get transactionsStream {
    return _transactionsCollection
        .orderBy('date', descending: true)
        .snapshots()
        .map((QuerySnapshot snapshot) {
      return snapshot.docs
          .map<Transaction>(
            (doc) => transactionFromFirestore(doc as DocumentSnapshot),
          )
          .toList();
    });
  }

  Future<void> addTransaction(Transaction transaction) {
    return _transactionsCollection.add({
      'amount': transaction.amount,
      'category': transaction.category.name,
      'type': transaction.type.name,
      'date': Timestamp.fromDate(transaction.date),
      'description': transaction.description,
    }).then((_) {
      notifyListeners();
    });
  }

  Future<void> addTransactionRaw({
    required double amount,
    required String category,
    required String type,
    required DateTime date,
    required String description,
  }) {
    return _transactionsCollection.add({
      'amount': amount,
      'category': category,
      'type': type,
      'date': Timestamp.fromDate(date),
      'description': description,
    });
  }

  // --- Dynamic Dashboard Data Calculations (STREAMS) ---

  Stream<double> get totalBalanceStream {
    return transactionsStream.map((transactions) {
      final double income = transactions
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (sum, item) => sum + item.amount);
      final double expense = transactions
          .where((t) => t.type == TransactionType.expense)
          .fold(0.0, (sum, item) => sum + item.amount);
      return income - expense;
    });
  }

  Stream<double> get monthlyExpenseStream {
    return transactionsStream.map((transactions) {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      return transactions
          .where((t) => t.type == TransactionType.expense)
          .where((t) =>
              t.date.isAfter(startOfMonth) ||
              t.date.isAtSameMomentAs(startOfMonth))
          .fold(0.0, (sum, item) => sum + item.amount);
    });
  }

  // Legacy Future properties (backed by transactions stream)
  Future<double> get totalBalance => totalBalanceStream.first;
  Future<double> get monthlyExpense => monthlyExpenseStream.first;

  Future<double> get previousMonthlyExpense async {
    final transactions = await transactionsStream.first;
    final now = DateTime.now();
    final previousMonth = now.month == 1 ? 12 : now.month - 1;
    final previousYear = now.month == 1 ? now.year - 1 : now.year;
    final startOfPrev = DateTime(previousYear, previousMonth, 1);
    final startOfThis = DateTime(now.year, now.month, 1);

    return transactions
        .where((t) => t.type == TransactionType.expense)
        .where((t) =>
            (t.date.isAtSameMomentAs(startOfPrev) ||
                t.date.isAfter(startOfPrev)) &&
            t.date.isBefore(startOfThis))
        .fold<double>(0.0, (sum, item) => sum + item.amount);
  }

  /// Returns a list of total expenses per month for the last [months] months,
  /// ordered from oldest to newest.
  Future<List<double>> historicalMonthlyExpense({int months = 6}) async {
    final transactions = await transactionsStream.first;
    final now = DateTime.now();

    // Prepare buckets for each month (oldest first)
    final List<DateTime> monthStarts = [];
    for (int i = months - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      monthStarts.add(DateTime(date.year, date.month, 1));
    }

    final List<double> monthlyTotals =
        List<double>.filled(monthStarts.length, 0.0);

    for (final t in transactions) {
      if (t.type != TransactionType.expense) continue;

      for (var i = 0; i < monthStarts.length; i++) {
        final start = monthStarts[i];
        final end = (i + 1 < monthStarts.length)
            ? monthStarts[i + 1]
            : DateTime(start.year, start.month + 1, 1);

        final afterStart =
            t.date.isAtSameMomentAs(start) || t.date.isAfter(start);
        final beforeEnd = t.date.isBefore(end);

        if (afterStart && beforeEnd) {
          monthlyTotals[i] += t.amount;
          break;
        }
      }
    }

    return monthlyTotals;
  }

  Stream<Map<ExpenseCategory, double>> get expensesByCategoryStream {
    return transactionsStream.map((transactions) {
      final expenseTransactions =
          transactions.where((t) => t.type == TransactionType.expense);
      final Map<ExpenseCategory, double> categoryMap = {};
      for (final category in ExpenseCategory.values) {
        if (category != ExpenseCategory.salary &&
            category != ExpenseCategory.gift) {
          final total = expenseTransactions
              .where((t) => t.category == category)
              .fold(0.0, (sum, item) => sum + item.amount);
          if (total > 0) {
            categoryMap[category] = total;
          }
        }
      }
      return categoryMap;
    });
  }

  Future<Map<ExpenseCategory, double>> get expensesByCategory async =>
      expensesByCategoryStream.first;

  // Monthly expenses split by category (current calendar month)
  Stream<Map<ExpenseCategory, double>> get monthlyExpensesByCategoryStream {
    return transactionsStream.map((transactions) {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final expenseTransactions = transactions
          .where((t) => t.type == TransactionType.expense)
          .where((t) =>
              t.date.isAfter(startOfMonth) ||
              t.date.isAtSameMomentAs(startOfMonth));

      final Map<ExpenseCategory, double> categoryMap = {};
      for (final category in ExpenseCategory.values) {
        if (category != ExpenseCategory.salary &&
            category != ExpenseCategory.gift) {
          final total = expenseTransactions
              .where((t) => t.category == category)
              .fold<double>(0.0, (sum, item) => sum + item.amount);
          if (total > 0) {
            categoryMap[category] = total;
          }
        }
      }
      return categoryMap;
    });
  }

  // Assets and Liabilities
  final List<Asset> _assets = [];
  final List<Liability> _liabilities = [];

  double get totalAssets => _assets.fold(0.0, (sum, item) => sum + item.value);

  double get totalLiabilities =>
      _liabilities.fold(0.0, (sum, item) => sum + item.amount);

  double get netWorth => totalAssets - totalLiabilities;

  List<double> get historicalNetWorth => [];

  String get predictiveInsight => 'Add your first transaction to see insights!';

  // Goals
  final List<Goal> _goals = [];

  List<Goal> get goals => _goals;

  void addGoal(Goal newGoal) {
    _goals.add(newGoal);
    notifyListeners();
  }

  void removeGoal(String id) {
    _goals.removeWhere((goal) => goal.id == id);
    notifyListeners();
  }

  void updateGoal(Goal updated) {
    final index = _goals.indexWhere((goal) => goal.id == updated.id);
    if (index != -1) {
      _goals[index] = updated;
      notifyListeners();
    }
  }

  // Firestore-backed goals

  Stream<List<Goal>> get goalsStream {
    return _goalsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map<Goal>((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Goal(
          id: doc.id,
          name: data['name'] as String? ?? '',
          targetAmount: (data['targetAmount'] as num?)?.toDouble() ?? 0.0,
          currentAmount: (data['currentAmount'] as num?)?.toDouble() ?? 0.0,
          deadline:
              (data['deadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
          priority: data['priority'] as String? ?? 'Medium',
        );
      }).toList();
    });
  }

  Future<void> addGoalToFirestore(Goal goal) {
    return _goalsCollection.add({
      'name': goal.name,
      'targetAmount': goal.targetAmount,
      'currentAmount': goal.currentAmount,
      'deadline': Timestamp.fromDate(goal.deadline),
      'priority': goal.priority,
    });
  }

  Future<void> updateGoalInFirestore(Goal goal) {
    return _goalsCollection.doc(goal.id).update({
      'name': goal.name,
      'targetAmount': goal.targetAmount,
      'currentAmount': goal.currentAmount,
      'deadline': Timestamp.fromDate(goal.deadline),
      'priority': goal.priority,
    });
  }

  Future<void> removeGoalFromFirestore(String id) {
    return _goalsCollection.doc(id).delete();
  }

  // Bills
  final List<Bill> _bills = [];

  List<Bill> get bills => _bills;

  void addBill(Bill newBill) {
    _bills.add(newBill);
    notifyListeners();
  }

  void togglePaidStatus(String billId) {
    final index = _bills.indexWhere((bill) => bill.id == billId);
    if (index != -1) {
      _bills[index] = _bills[index].copyWith(isPaid: !_bills[index].isPaid);
      if (_bills[index].isPaid) {
        unlockAchievement('a4');
      }
      notifyListeners();
    }
  }

  void removeBill(String id) {
    _bills.removeWhere((bill) => bill.id == id);
    notifyListeners();
  }

  // Firestore-backed bills

  Stream<List<Bill>> get billsStream {
    return _billsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map<Bill>((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Bill(
          id: doc.id,
          name: data['name'] as String? ?? '',
          amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
          dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isPaid: data['isPaid'] as bool? ?? false,
          repeatCycle: data['repeatCycle'] as String? ?? 'One-time',
        );
      }).toList();
    });
  }

  Future<void> addBillToFirestore(Bill bill) {
    return _billsCollection.add({
      'name': bill.name,
      'amount': bill.amount,
      'dueDate': Timestamp.fromDate(bill.dueDate),
      'isPaid': bill.isPaid,
      'repeatCycle': bill.repeatCycle,
    });
  }

  Future<void> updateBillInFirestore(Bill bill) {
    return _billsCollection.doc(bill.id).update({
      'name': bill.name,
      'amount': bill.amount,
      'dueDate': Timestamp.fromDate(bill.dueDate),
      'isPaid': bill.isPaid,
      'repeatCycle': bill.repeatCycle,
    });
  }

  Future<void> removeBillFromFirestore(String id) {
    return _billsCollection.doc(id).delete();
  }

  Future<void> togglePaidStatusInFirestore(String billId, bool isPaid) {
    return _billsCollection.doc(billId).update({'isPaid': isPaid});
  }

  // Achievements
  final List<Achievement> _achievements = [
    Achievement(
      id: 'a1',
      title: 'First Steps',
      description: 'Log your first transaction',
      icon: Icons.rocket_launch_rounded,
      isUnlocked: false,
    ),
    Achievement(
      id: 'a2',
      title: 'Budget Master',
      description: 'Stay within budget for 30 days',
      icon: Icons.military_tech_rounded,
      isUnlocked: false,
    ),
    Achievement(
      id: 'a3',
      title: 'Power Saver',
      description: 'Save ₹50,000 for a goal',
      icon: Icons.savings_rounded,
      isUnlocked: false,
    ),
    Achievement(
      id: 'a4',
      title: 'Bill Slayer',
      description: 'Pay 3 bills on time',
      icon: Icons.receipt_long_rounded,
      isUnlocked: false,
    ),
  ];

  List<Achievement> get achievements => _achievements;

  void unlockAchievement(String id) {
    final index = _achievements.indexWhere((a) => a.id == id);
    if (index != -1 && !_achievements[index].isUnlocked) {
      _achievements[index] = _achievements[index].copyWith(isUnlocked: true);
      _achievementsCollection.doc(id).set({'isUnlocked': true});
      notifyListeners();
    }
  }

  void toggleAchievement(String id) {
    final index = _achievements.indexWhere((a) => a.id == id);
    if (index != -1) {
      final bool currentlyUnlocked = _achievements[index].isUnlocked;
      final bool newValue = !currentlyUnlocked;
      _achievements[index] =
          _achievements[index].copyWith(isUnlocked: newValue);
      _achievementsCollection.doc(id).set({'isUnlocked': newValue});
      notifyListeners();
    }
  }

  void _listenToAchievements() {
    _achievementsCollection.snapshots().listen((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String docId = doc.id;
        final bool isUnlocked = data['isUnlocked'] as bool? ?? false;

        final int index = _achievements.indexWhere((a) => a.id == docId);
        if (index != -1) {
          _achievements[index] =
              _achievements[index].copyWith(isUnlocked: isUnlocked);
        }
      }
      notifyListeners();
    });
  }

  // Challenges
  final List<Challenge> _challenges = [
    Challenge(
      id: 'c1',
      title: 'No-Spend Day',
      description: 'Avoid any expenses today',
      progress: 0.0,
      target: 1.0,
    ),
    Challenge(
      id: 'c2',
      title: 'Reduce Food Spending',
      description: 'Cut food expenses by 10% this week',
      progress: 0.0,
      target: 1.0,
    ),
  ];

  List<Challenge> get challenges => _challenges;

  void _listenToChallenges() {
    // Ensure default documents exist
    for (final challenge in _challenges) {
      _challengesCollection.doc(challenge.id).set({
        'title': challenge.title,
        'description': challenge.description,
        'progress': challenge.progress,
        'target': challenge.target,
      }, SetOptions(merge: true));
    }

    _challengesCollection.snapshots().listen((snapshot) {
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String docId = doc.id;
        final double progress = (data['progress'] as num?)?.toDouble() ?? 0.0;
        final double target = (data['target'] as num?)?.toDouble() ?? 1.0;
        final String? title = data['title'] as String?;
        final String? description = data['description'] as String?;

        final int index = _challenges.indexWhere((c) => c.id == docId);
        if (index != -1) {
          _challenges[index] = _challenges[index].copyWith(
            title: title,
            description: description,
            progress: progress,
            target: target,
          );
        }
      }
      notifyListeners();
    });
  }

  Future<void> updateChallengeProgress(String id, double progress,
      {double? target}) {
    final int index = _challenges.indexWhere((c) => c.id == id);
    if (index != -1) {
      final updated = _challenges[index].copyWith(
          progress: progress, target: target ?? _challenges[index].target);
      _challenges[index] = updated;
      _challengesCollection.doc(id).set({
        'title': updated.title,
        'description': updated.description,
        'progress': updated.progress,
        'target': updated.target,
      }, SetOptions(merge: true));
      notifyListeners();
    }
    return Future.value();
  }

  // Shared Wallets
  final List<SharedWallet> _sharedWallets = [];

  List<SharedWallet> get sharedWallets => _sharedWallets;

  void addSharedWallet(SharedWallet newWallet) {
    _sharedWallets.add(newWallet);
    notifyListeners();
  }

  void removeSharedWallet(String id) {
    _sharedWallets.removeWhere((wallet) => wallet.id == id);
    notifyListeners();
  }

  // Firestore-backed shared wallets

  Stream<List<SharedWallet>> get sharedWalletsStream {
    return _sharedWalletsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map<SharedWallet>((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final members = (data['members'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];
        return SharedWallet(
          id: doc.id,
          name: data['name'] as String? ?? '',
          members: members,
          balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    });
  }

  Future<void> addSharedWalletToFirestore(SharedWallet wallet) {
    return _sharedWalletsCollection.add({
      'name': wallet.name,
      'members': wallet.members,
      'balance': wallet.balance,
    });
  }

  Future<void> updateSharedWalletInFirestore(SharedWallet wallet) {
    return _sharedWalletsCollection.doc(wallet.id).update({
      'name': wallet.name,
      'members': wallet.members,
      'balance': wallet.balance,
    });
  }

  Future<void> removeSharedWalletFromFirestore(String id) {
    return _sharedWalletsCollection.doc(id).delete();
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
    for (final member in members) {
      owedAmounts[member] = splitAmount;
    }
    return owedAmounts;
  }

  // Referral System
  Future<String> generateReferralCode(String userId) async {
    final code = _generateRandomCode(6);
    await _usersCollection.doc(userId).set({
      'referralCode': code,
      'referredBy': null,
      'referralCount': 0,
    }, SetOptions(merge: true));
    return code;
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
      length,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ));
  }

  Future<void> trackReferral(String referrerId) async {
    await _usersCollection.doc(referrerId).update({
      'referralCount': FieldValue.increment(1),
    });
  }

  Future<String?> getReferralCode(String userId) async {
    final doc = await _usersCollection.doc(userId).get();
    return doc['referralCode'] as String?;
  }
}
