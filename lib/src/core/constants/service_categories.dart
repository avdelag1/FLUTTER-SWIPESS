class ServiceCategory {
  const ServiceCategory({
    required this.value,
    required this.label,
    required this.group,
  });

  final String value;
  final String label;
  final String group;
}

/// Worker/service categories from Capacitor `serviceCategories.ts`.
const serviceCategories = <ServiceCategory>[
  ServiceCategory(value: 'house_cleaner', label: 'House Cleaner', group: 'Home & Property'),
  ServiceCategory(value: 'handyman', label: 'Handyman', group: 'Home & Property'),
  ServiceCategory(value: 'plumber', label: 'Plumber', group: 'Home & Property'),
  ServiceCategory(value: 'electrician', label: 'Electrician', group: 'Home & Property'),
  ServiceCategory(value: 'gardener', label: 'Gardener / Landscaper', group: 'Home & Property'),
  ServiceCategory(value: 'pool_cleaner', label: 'Pool Cleaner', group: 'Home & Property'),
  ServiceCategory(value: 'house_painter', label: 'House Painter', group: 'Home & Property'),
  ServiceCategory(value: 'massage_therapist', label: 'Massage Therapist', group: 'Wellness'),
  ServiceCategory(value: 'yoga', label: 'Yoga Instructor', group: 'Wellness'),
  ServiceCategory(value: 'personal_trainer', label: 'Personal Trainer', group: 'Wellness'),
  ServiceCategory(value: 'beauty', label: 'Makeup & Hair', group: 'Wellness'),
  ServiceCategory(value: 'nanny', label: 'Babysitter / Nanny', group: 'Care'),
  ServiceCategory(value: 'pet_care', label: 'Pet Sitter', group: 'Care'),
  ServiceCategory(value: 'driver', label: 'Private Driver', group: 'Transport'),
  ServiceCategory(value: 'mechanic', label: 'Mechanic', group: 'Transport'),
  ServiceCategory(value: 'chef', label: 'Private Chef', group: 'Events'),
  ServiceCategory(value: 'bartender', label: 'Bartender', group: 'Events'),
  ServiceCategory(value: 'event_planner', label: 'Event Planner', group: 'Events'),
  ServiceCategory(value: 'language_teacher', label: 'Language Teacher', group: 'Education'),
  ServiceCategory(value: 'scuba_instructor', label: 'Scuba Instructor', group: 'Adventure'),
  ServiceCategory(value: 'surf_instructor', label: 'Surf Instructor', group: 'Adventure'),
  ServiceCategory(value: 'sailing_instructor', label: 'Boat Captain', group: 'Adventure'),
  ServiceCategory(value: 'photographer', label: 'Photographer', group: 'Creative'),
  ServiceCategory(value: 'videographer', label: 'Videographer', group: 'Creative'),
  ServiceCategory(value: 'it_support', label: 'IT Support', group: 'Creative'),
  ServiceCategory(value: 'translator', label: 'Translator', group: 'Professional'),
  ServiceCategory(value: 'accountant', label: 'Accountant', group: 'Professional'),
  ServiceCategory(value: 'lawyer', label: 'Lawyer', group: 'Professional'),
  ServiceCategory(value: 'other', label: 'Other service', group: 'Other'),
];

String serviceCategoryLabel(String? value) {
  if (value == null) return '';
  for (final item in serviceCategories) {
    if (item.value == value) return item.label;
  }
  return value;
}
