import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../models/bill.dart';
import '../../models/goal.dart';
import '../../providers/transaction_manager.dart';
import '../../main.dart' show AddTransactionPage, AddTransactionOptionsPage;

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manager = Provider.of<TransactionManager>(context, listen: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total balance card (based on all transactions: income - expenses)
          StreamBuilder<double>(
            stream: manager.totalBalanceStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final balance = snapshot.data ?? 0.0;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 20, end: 0),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final opacity = 1 - (value / 20).clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, value),
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
                child: _buildBalanceCard(context, balance),
              );
            },
          ),

          const SizedBox(height: 12),

          // Savings streak / activity ring
          StreamBuilder<List<Transaction>>(
            stream: manager.transactionsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final txs = snapshot.data ?? [];
              final streakDays = _calculateExpenseStreakDays(txs);
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 16, end: 0),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final opacity = 1 - (value / 16).clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, value),
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
                child: _buildSavingsStreakChip(theme, streakDays),
              );
            },
          ),

          const SizedBox(height: 12),

          // Monthly income & expense summary
          StreamBuilder<List<Transaction>>(
            stream: manager.transactionsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final txs = snapshot.data ?? [];
              final now = DateTime.now();
              final startOfMonth = DateTime(now.year, now.month, 1);

              double income = 0.0;
              double expense = 0.0;
              for (final t in txs) {
                if (t.date.isBefore(startOfMonth)) continue;
                if (t.type == TransactionType.income) {
                  income += t.amount;
                } else if (t.type == TransactionType.expense) {
                  expense += t.amount;
                }
              }

              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 24, end: 0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final opacity = 1 - (value / 24).clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, value),
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
                child: _buildMonthlySummaryCard(income, expense),
              );
            },
          ),

          const SizedBox(height: 16),

          // Spending breakdown (categories) + insights
          _buildSectionTitle('Spending Breakdown'),
          StreamBuilder<Map<ExpenseCategory, double>>(
            stream: manager.expensesByCategoryStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData || (snapshot.data?.isEmpty ?? true)) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 28, end: 0),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    final opacity = 1 - (value / 28).clamp(0.0, 1.0);
                    return Transform.translate(
                      offset: Offset(0, value),
                      child: Opacity(opacity: opacity, child: child),
                    );
                  },
                  child: const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No spending data yet. Add some expenses to see the breakdown.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                );
              }

              final data = snapshot.data!;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 28, end: 0),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final opacity = 1 - (value / 28).clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, value),
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
                child: _buildSpendingChartAndInsights(theme, data),
              );
            },
          ),

          const SizedBox(height: 16),

          // Upcoming bills + goals mini strip
          _buildSectionTitle('Upcoming This Month'),
          StreamBuilder<List<Bill>>(
            stream: manager.billsStream,
            builder: (context, billSnapshot) {
              if (billSnapshot.connectionState == ConnectionState.waiting &&
                  !billSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final bills = billSnapshot.data ?? [];

              return StreamBuilder<List<Goal>>(
                stream: manager.goalsStream,
                builder: (context, goalSnapshot) {
                  if (goalSnapshot.connectionState == ConnectionState.waiting &&
                      !goalSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final goals = goalSnapshot.data ?? [];

                  final now = DateTime.now();
                  final todayDate = DateTime(now.year, now.month, now.day);

                  // Next unpaid bill by upcoming due date
                  Bill? nextBill;
                  final unpaidUpcomingBills =
                      bills.where((b) => !b.isPaid).where((b) {
                    final d = DateTime(
                        b.dueDate.year, b.dueDate.month, b.dueDate.day);
                    return !d.isBefore(todayDate);
                  }).toList();
                  if (unpaidUpcomingBills.isNotEmpty) {
                    unpaidUpcomingBills
                        .sort((a, b) => a.dueDate.compareTo(b.dueDate));
                    nextBill = unpaidUpcomingBills.first;
                  }

                  // Closest goal by highest progress but not yet completed
                  Goal? closestGoal;
                  final activeGoals = goals
                      .where((g) => g.targetAmount > 0)
                      .where((g) => g.currentAmount < g.targetAmount)
                      .toList();
                  if (activeGoals.isNotEmpty) {
                    activeGoals.sort((a, b) {
                      final pa = a.currentAmount / a.targetAmount;
                      final pb = b.currentAmount / b.targetAmount;
                      return pb.compareTo(pa);
                    });
                    closestGoal = activeGoals.first;
                  }

                  if (nextBill == null && closestGoal == null) {
                    return const Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No upcoming bills or active goals for this month yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (nextBill != null)
                          _buildUpcomingBillCard(theme, nextBill!),
                        if (nextBill != null && closestGoal != null)
                          const SizedBox(width: 12),
                        if (closestGoal != null)
                          _buildUpcomingGoalCard(theme, closestGoal!),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 16),
          _buildSectionTitle('Recent Transactions'),

          StreamBuilder<List<Transaction>>(
            stream: manager.transactionsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final transactions = snapshot.data ?? [];
              if (transactions.isEmpty) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 32, end: 0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    final opacity = 1 - (value / 32).clamp(0.0, 1.0);
                    return Transform.translate(
                      offset: Offset(0, value),
                      child: Opacity(opacity: opacity, child: child),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'No recent transactions yet. Start by adding an income or expense.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              final recent = transactions.take(5).toList();
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 32, end: 0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final opacity = 1 - (value / 32).clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(0, value),
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
                child: _buildTransactionList(theme, recent),
              );
            },
          ),
        ],
      ),
    );
  }

  int _calculateExpenseStreakDays(List<Transaction> txs) {
    if (txs.isEmpty) return 0;

    final expensesByDay = <DateTime, bool>{};
    for (final t in txs) {
      if (t.type != TransactionType.expense) continue;
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      expensesByDay[d] = true;
    }
    if (expensesByDay.isEmpty) return 0;

    int streak = 0;
    DateTime current = DateTime.now();
    while (true) {
      final dayKey = DateTime(current.year, current.month, current.day);
      if (expensesByDay[dayKey] == true) {
        streak += 1;
        current = current.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  Widget _buildSavingsStreakChip(ThemeData theme, int streakDays) {
    final hasStreak = streakDays > 0;
    final progress = (streakDays / 7).clamp(0.0, 1.0);

    final text = hasStreak
        ? '$streakDays-day expense tracking streak'
        : 'Start tracking expenses to build your streak';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E88E5).withOpacity(0.12),
            const Color(0xFF42A5F5).withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF1E88E5).withOpacity(0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1E88E5),
                        Color(0xFF42A5F5),
                      ],
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          value: hasStreak ? progress : 0.0,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                          backgroundColor:
                              Colors.white.withOpacity(hasStreak ? 0.18 : 0.1),
                        ),
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // soft glow behind the flame
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.55),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          // back flame layer (darker, slightly lower)
                          Transform.translate(
                            offset: const Offset(0, 1.2),
                            child: Icon(
                              Icons.local_fire_department,
                              size: 20,
                              color: const Color(0xFFFFA000).withOpacity(0.95),
                            ),
                          ),
                          // front flame highlight (brighter, slightly up)
                          Transform.translate(
                            offset: const Offset(0, -0.6),
                            child: const Icon(
                              Icons.local_fire_department,
                              size: 18,
                              color: Color(0xFFFFF3E0),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasStreak
                          ? 'Hit 7 days for a perfect week streak'
                          : 'Log at least one expense today to begin',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Icon(
              hasStreak ? Icons.emoji_events_rounded : Icons.more_horiz_rounded,
              color: hasStreak
                  ? const Color(0xFFFB8C00)
                  : theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: theme.colorScheme.onSurface.withOpacity(0.9),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthlySummaryCard(double monthlyIncome, double monthlyExpense) {
    final incomeText = NumberFormat.currency(symbol: '₹').format(monthlyIncome);
    final expenseText =
        NumberFormat.currency(symbol: '\u20b9').format(monthlyExpense);

    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final hasMovement = monthlyIncome != 0 || monthlyExpense != 0;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                const Color(0xFFE3F2FD),
                const Color(0xFFBBDEFB).withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFF1E88E5).withOpacity(0.16),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A8A).withOpacity(0.18),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.45),
                blurRadius: 18,
                spreadRadius: -6,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This month so far',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.arrow_downward_rounded,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                incomeText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.arrow_upward_rounded,
                                size: 16,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                expenseText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(
                      hasMovement
                          ? Icons.trending_up_rounded
                          : Icons.timelapse_rounded,
                      color: hasMovement ? Colors.green : theme.disabledColor,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasMovement
                          ? 'Tracking this month\'s flow'
                          : 'No activity yet',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalanceCard(BuildContext context, double balance) {
    final bool isNegative = balance < 0;
    final String balanceText =
        NumberFormat.currency(symbol: '₹').format(balance.abs());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: isNegative
                    ? [
                        const Color(0xFFEF5350).withOpacity(0.9),
                        const Color(0xFFF57C00).withOpacity(0.85),
                      ]
                    : [
                        const Color(0xFF1E88E5).withOpacity(0.95),
                        const Color(0xFF42A5F5).withOpacity(0.9),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.28),
                width: 1.2,
              ),
              boxShadow: [
                // main directional shadow for strong 3D depth
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 26,
                  offset: const Offset(0, 18),
                ),
                // soft ambient shadow to keep edges smooth on light backgrounds
                BoxShadow(
                  color: const Color(0xFF1E88E5).withOpacity(0.35),
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Balance',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        balanceText,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (isNegative)
                        Text(
                          '(Outstanding)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _QuickActionChip(
                            icon: Icons.arrow_downward_rounded,
                            label: 'Add Income',
                            backgroundColor: Colors.green.withOpacity(0.16),
                            borderColor: Colors.green.withOpacity(0.32),
                            iconColor: Colors.green.shade50,
                            textColor: Colors.green.shade50,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => const AddTransactionPage(
                                    initialType: TransactionType.income,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _QuickActionChip(
                            icon: Icons.arrow_upward_rounded,
                            label: 'Add Expense',
                            backgroundColor: Colors.red.withOpacity(0.16),
                            borderColor: Colors.red.withOpacity(0.32),
                            iconColor: Colors.red.shade50,
                            textColor: Colors.red.shade50,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => const AddTransactionPage(
                                    initialType: TransactionType.expense,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _QuickActionChip(
                            icon: Icons.swap_horiz_rounded,
                            label: 'Add Transfer',
                            backgroundColor:
                                const Color(0xFF1E88E5).withOpacity(0.20),
                            borderColor:
                                const Color(0xFF42A5F5).withOpacity(0.40),
                            iconColor: Colors.white,
                            textColor: Colors.white,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) =>
                                      const AddTransactionOptionsPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      Icon(
                        Icons.analytics_outlined,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionList(
    ThemeData theme,
    List<Transaction> transactions,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: transactions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final t = transactions[index];
          final isIncome = t.type == TransactionType.income;
          final amountText =
              NumberFormat.currency(symbol: '₹').format(t.amount.abs());
          final dateText = DateFormat('dd MMM').format(t.date);

          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isIncome ? Colors.green.shade50 : Colors.red.shade50,
              child: Icon(
                _iconForCategory(t.category),
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),
            title: Text(
              t.description.isNotEmpty ? t.description : t.category.name,
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Text(
              '${t.category.name} • $dateText',
              style: theme.textTheme.bodySmall,
            ),
            trailing: Text(
              (isIncome ? '+ ' : '- ') + amountText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpendingChartAndInsights(
    ThemeData theme,
    Map<ExpenseCategory, double> data,
  ) {
    final total = data.values.fold<double>(0.0, (sum, v) => sum + v);

    return Card(
      elevation: 4,
      shadowColor: theme.colorScheme.primary.withOpacity(0.28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Categories (X-axis)',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
                Text(
                  'Monthly spend (₹) (Y-axis)',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.keys.length) {
                            return const SizedBox.shrink();
                          }
                          final category = data.keys.elementAt(index);
                          final label = _labelForCategoryName(category.name);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < data.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: data.values.elementAt(i),
                            width: 18,
                            borderRadius: BorderRadius.circular(6),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1E88E5),
                                Color(0xFF90CAF9),
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                if (total <= 0) {
                  return const Text(
                    'No insights yet. Add some expenses to see suggestions.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  );
                }

                final topEntry = data.entries.reduce(
                  (a, b) => a.value >= b.value ? a : b,
                );
                final topPercent = (topEntry.value / total * 100);
                final categoryName = topEntry.key.name;
                final totalText =
                    NumberFormat.currency(symbol: '₹').format(total);
                final categoryLabel = _labelForCategoryName(categoryName);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top spending category: $categoryLabel '
                      '(${topPercent.toStringAsFixed(1)}% of your expenses).',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total spent across categories this month: $totalText.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey.shade700),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _labelForCategoryName(String rawName) {
    final name = rawName.toLowerCase();

    if (name.contains('food') || name.contains('groc')) {
      return 'Food';
    }
    if (name.contains('travel') ||
        name.contains('flight') ||
        name.contains('trip')) {
      return 'Travel';
    }
    if (name.contains('shop') || name.contains('mall')) {
      return 'Shopping';
    }
    if (name.contains('bill') || name.contains('utilit')) {
      return 'Bills';
    }
    if (name.contains('rent') ||
        name.contains('home') ||
        name.contains('house')) {
      return 'Home';
    }
    if (name.contains('edu') ||
        name.contains('school') ||
        name.contains('course')) {
      return 'Education';
    }
    if (name.contains('health') ||
        name.contains('med') ||
        name.contains('doctor')) {
      return 'Health';
    }
    if (name.contains('salary') || name.contains('income')) {
      return 'Income';
    }
    if (name.contains('gift')) {
      return 'Gifts';
    }
    if (name.contains('entertain') ||
        name.contains('movie') ||
        name.contains('fun')) {
      return 'Entertain';
    }

    // Fallback: keep it short but readable
    return rawName.length > 9 ? rawName.substring(0, 9) : rawName;
  }

  Widget _buildUpcomingBillCard(ThemeData theme, Bill bill) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final dueDate =
        DateTime(bill.dueDate.year, bill.dueDate.month, bill.dueDate.day);
    final diffDays = dueDate.difference(todayDate).inDays;

    String subtitle;
    Color chipColor;
    IconData chipIcon;

    if (diffDays < 0) {
      subtitle = 'Overdue by ${diffDays.abs()} day${diffDays == -1 ? '' : 's'}';
      chipColor = Colors.red;
      chipIcon = Icons.warning_amber_rounded;
    } else if (diffDays == 0) {
      subtitle = 'Due today';
      chipColor = Colors.orange;
      chipIcon = Icons.access_time_rounded;
    } else {
      subtitle = 'Due in $diffDays day${diffDays == 1 ? '' : 's'}';
      chipColor = theme.colorScheme.primary;
      chipIcon = Icons.calendar_today_rounded;
    }

    return SizedBox(
      width: 220,
      child: Card(
        color: const Color(0xFFFFEBEE),
        elevation: 4,
        shadowColor: Colors.red.shade200,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Next bill',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.receipt_long_rounded,
                      size: 18, color: Colors.red.shade400),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                bill.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB71C1C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${bill.amount.toStringAsFixed(0)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Due ${DateFormat('dd MMM').format(bill.dueDate)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chipColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chipIcon, size: 14, color: chipColor),
                    const SizedBox(width: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: chipColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingGoalCard(ThemeData theme, Goal goal) {
    final progress = goal.targetAmount <= 0
        ? 0.0
        : (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
    final percent = (progress * 100).toStringAsFixed(0);
    final remaining =
        (goal.targetAmount - goal.currentAmount).clamp(0.0, double.infinity);

    return SizedBox(
      width: 220,
      child: Card(
        color: const Color(0xFFE8F5E9),
        elevation: 4,
        shadowColor: const Color(0xFF81C784),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Closest goal',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF2E7D32),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.flag_rounded,
                      size: 18, color: Color(0xFF43A047)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                goal.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$percent% complete',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF43A047),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                remaining <= 0
                    ? 'You have fully funded this goal!'
                    : '₹${remaining.toStringAsFixed(0)} left to reach this goal.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(ExpenseCategory category) {
    final name = category.name.toLowerCase();

    if (name.contains('food') || name.contains('groc')) {
      return Icons.restaurant_rounded;
    }
    if (name.contains('travel') ||
        name.contains('flight') ||
        name.contains('trip')) {
      return Icons.flight_takeoff_rounded;
    }
    if (name.contains('shop') || name.contains('mall')) {
      return Icons.shopping_bag_rounded;
    }
    if (name.contains('bill') || name.contains('utilit')) {
      return Icons.receipt_long_rounded;
    }
    if (name.contains('rent') ||
        name.contains('home') ||
        name.contains('house')) {
      return Icons.home_rounded;
    }
    if (name.contains('edu') ||
        name.contains('school') ||
        name.contains('course')) {
      return Icons.school_rounded;
    }
    if (name.contains('health') ||
        name.contains('med') ||
        name.contains('doctor')) {
      return Icons.health_and_safety_rounded;
    }
    if (name.contains('salary') || name.contains('income')) {
      return Icons.payments_rounded;
    }
    if (name.contains('gift')) {
      return Icons.card_giftcard_rounded;
    }
    if (name.contains('entertain') ||
        name.contains('movie') ||
        name.contains('fun')) {
      return Icons.movie_rounded;
    }

    return Icons.category_rounded;
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;
  final Color? textColor;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.white.withOpacity(0.18);
    final border = borderColor ?? Colors.white.withOpacity(0.32);
    final iconCol = iconColor ?? Colors.white;
    final textCol = textColor ?? Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: bg.withOpacity(0.7),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconCol),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textCol,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
