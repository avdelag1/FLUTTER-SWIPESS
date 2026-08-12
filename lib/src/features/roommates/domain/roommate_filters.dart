/// Cap RoommateFiltersSheet — local filter state for roommate deck.
class RoommateFilters {
  const RoommateFilters({
    this.minBudget = 500,
    this.maxBudget = 3000,
    this.minAge = 18,
    this.maxAge = 50,
    this.city,
  });

  final double minBudget;
  final double maxBudget;
  final int minAge;
  final int maxAge;
  final String? city;

  RoommateFilters copyWith({
    double? minBudget,
    double? maxBudget,
    int? minAge,
    int? maxAge,
    String? city,
    bool clearCity = false,
  }) {
    return RoommateFilters(
      minBudget: minBudget ?? this.minBudget,
      maxBudget: maxBudget ?? this.maxBudget,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      city: clearCity ? null : (city ?? this.city),
    );
  }
}
