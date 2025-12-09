enum LiabilityType { mortgage, loan, creditCard }

class Liability {
  final String name;
  final double amount;
  final LiabilityType type;

  Liability({required this.name, required this.amount, required this.type});
}
