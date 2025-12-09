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
