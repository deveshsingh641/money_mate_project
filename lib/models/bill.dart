class Bill {
  final String id;
  final String name;
  final double amount;
  final DateTime dueDate;
  final bool isPaid;
  final String repeatCycle; // e.g., One-time, Monthly, Yearly

  Bill({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
    this.repeatCycle = 'One-time',
  });

  Bill copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? dueDate,
    bool? isPaid,
    String? repeatCycle,
  }) {
    return Bill(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      repeatCycle: repeatCycle ?? this.repeatCycle,
    );
  }
}
