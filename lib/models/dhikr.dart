class Dhikr {
  final int id;
  final String arabic;
  final String transliteration;
  final String translation;
  final int target;
  final int colorIndex;
  final bool isCustom;

  const Dhikr({
    required this.id,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.target,
    required this.colorIndex,
    this.isCustom = false,
  });

  // Convert to/from JSON for local storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'arabic': arabic,
    'transliteration': transliteration,
    'translation': translation,
    'target': target,
    'colorIndex': colorIndex,
    'isCustom': isCustom,
  };

  factory Dhikr.fromJson(Map<String, dynamic> json) => Dhikr(
    id: json['id'],
    arabic: json['arabic'],
    transliteration: json['transliteration'],
    translation: json['translation'],
    target: json['target'],
    colorIndex: json['colorIndex'],
    isCustom: json['isCustom'] ?? false,
  );
}
