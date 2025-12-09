enum AssetType { savings, investment, property }

class Asset {
  final String name;
  final double value;
  final AssetType type;

  Asset({required this.name, required this.value, required this.type});
}
