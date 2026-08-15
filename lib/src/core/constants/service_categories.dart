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

/// Cap `SERVICE_GROUPS` — display order for worker create / discovery filters.
const serviceGroups = <String>[
  'Home & Property',
  'Personal Care & Wellness',
  'Child & Pet Care',
  'Transportation',
  'Culinary & Events',
  'Education & Languages',
  'Water & Adventure',
  'Creative & Tech',
  'Professional',
  'Other',
];

/// Worker/service categories from Capacitor `serviceCategories.ts`.
const serviceCategories = <ServiceCategory>[
  // Home & Property
  ServiceCategory(
    value: 'house_cleaner',
    label: 'House Cleaner / Cleaning Lady',
    group: 'Home & Property',
  ),
  ServiceCategory(
    value: 'handyman',
    label: 'Handyman / General Maintenance',
    group: 'Home & Property',
  ),
  ServiceCategory(
    value: 'maintenance_tech',
    label: 'Maintenance Technician',
    group: 'Home & Property',
  ),
  ServiceCategory(
    value: 'house_painter',
    label: 'House Painter',
    group: 'Home & Property',
  ),
  ServiceCategory(value: 'plumber', label: 'Plumber', group: 'Home & Property'),
  ServiceCategory(
    value: 'electrician',
    label: 'Electrician',
    group: 'Home & Property',
  ),
  ServiceCategory(
    value: 'gardener',
    label: 'Gardener / Landscaper',
    group: 'Home & Property',
  ),
  ServiceCategory(
    value: 'pool_cleaner',
    label: 'Pool Cleaner & Maintenance',
    group: 'Home & Property',
  ),

  // Personal Care & Wellness
  ServiceCategory(
    value: 'massage_therapist',
    label: 'Massage Therapist',
    group: 'Personal Care & Wellness',
  ),
  ServiceCategory(
    value: 'yoga',
    label: 'Yoga Instructor',
    group: 'Personal Care & Wellness',
  ),
  ServiceCategory(
    value: 'meditation_coach',
    label: 'Meditation / Mindfulness Coach',
    group: 'Personal Care & Wellness',
  ),
  ServiceCategory(
    value: 'holistic_therapist',
    label: 'Holistic Therapist',
    group: 'Personal Care & Wellness',
  ),
  ServiceCategory(
    value: 'personal_trainer',
    label: 'Personal Trainer / Fitness Coach',
    group: 'Personal Care & Wellness',
  ),
  ServiceCategory(
    value: 'beauty',
    label: 'Makeup Artist & Hair Stylist',
    group: 'Personal Care & Wellness',
  ),
  ServiceCategory(
    value: 'nutritionist',
    label: 'Nutritionist / Meal Prep Chef',
    group: 'Personal Care & Wellness',
  ),

  // Child & Pet Care
  ServiceCategory(
    value: 'nanny',
    label: 'Babysitter / Nanny',
    group: 'Child & Pet Care',
  ),
  ServiceCategory(
    value: 'pet_care',
    label: 'Dog Sitter / Pet Sitter',
    group: 'Child & Pet Care',
  ),
  ServiceCategory(
    value: 'pet_groomer',
    label: 'Pet Groomer',
    group: 'Child & Pet Care',
  ),

  // Transportation
  ServiceCategory(
    value: 'driver',
    label: 'Chauffeur / Private Driver',
    group: 'Transportation',
  ),
  ServiceCategory(
    value: 'mechanic',
    label: 'Mechanic (Car / Moto / Bicycle)',
    group: 'Transportation',
  ),

  // Culinary & Events
  ServiceCategory(
    value: 'chef',
    label: 'Private Chef',
    group: 'Culinary & Events',
  ),
  ServiceCategory(
    value: 'bartender',
    label: 'Bartender / Mixologist',
    group: 'Culinary & Events',
  ),
  ServiceCategory(
    value: 'event_planner',
    label: 'Event Planner / Party Coordinator',
    group: 'Culinary & Events',
  ),

  // Education & Languages
  ServiceCategory(
    value: 'language_teacher',
    label: 'Language Teacher / Tutor',
    group: 'Education & Languages',
  ),
  ServiceCategory(
    value: 'music_teacher',
    label: 'Music Teacher',
    group: 'Education & Languages',
  ),
  ServiceCategory(
    value: 'dance_instructor',
    label: 'Dance Instructor',
    group: 'Education & Languages',
  ),

  // Water & Adventure
  ServiceCategory(
    value: 'scuba_instructor',
    label: 'Scuba Diving Instructor / Divemaster',
    group: 'Water & Adventure',
  ),
  ServiceCategory(
    value: 'surf_instructor',
    label: 'Surf Instructor',
    group: 'Water & Adventure',
  ),
  ServiceCategory(
    value: 'snorkeling_guide',
    label: 'Snorkeling Guide',
    group: 'Water & Adventure',
  ),
  ServiceCategory(
    value: 'sailing_instructor',
    label: 'Sailing / Boat Captain',
    group: 'Water & Adventure',
  ),
  ServiceCategory(
    value: 'fishing_guide',
    label: 'Fishing Guide',
    group: 'Water & Adventure',
  ),

  // Creative & Tech
  ServiceCategory(
    value: 'photographer',
    label: 'Photographer',
    group: 'Creative & Tech',
  ),
  ServiceCategory(
    value: 'videographer',
    label: 'Videographer / Drone Operator',
    group: 'Creative & Tech',
  ),
  ServiceCategory(
    value: 'graphic_designer',
    label: 'Graphic Designer',
    group: 'Creative & Tech',
  ),
  ServiceCategory(
    value: 'it_support',
    label: 'IT Support / Computer Repair',
    group: 'Creative & Tech',
  ),

  // Professional
  ServiceCategory(
    value: 'translator',
    label: 'Translator / Interpreter',
    group: 'Professional',
  ),
  ServiceCategory(
    value: 'accountant',
    label: 'Accountant / Bookkeeper',
    group: 'Professional',
  ),
  ServiceCategory(
    value: 'security',
    label: 'Security Guard',
    group: 'Professional',
  ),
  ServiceCategory(value: 'lawyer', label: 'Lawyer', group: 'Professional'),

  // Other
  ServiceCategory(value: 'other', label: 'Other Service', group: 'Other'),
];

/// Cap `SERVICE_SUBSPECIALTIES` — skills checkboxes after picking a service.
const serviceSubspecialties = <String, List<String>>{
  'massage_therapist': [
    'Swedish',
    'Deep Tissue',
    'Thai',
    'Sports',
    'Hot Stone',
    'Aromatherapy',
    'Reflexology',
    'Couples',
  ],
  'holistic_therapist': [
    'Reiki',
    'Energy Healing',
    'Acupuncture',
    'Crystal Healing',
    'Sound Therapy',
  ],
  'language_teacher': [
    'English',
    'Spanish',
    'French',
    'German',
    'Italian',
    'Chinese',
    'Portuguese',
    'Mayan',
  ],
  'music_teacher': ['Guitar', 'Piano', 'Singing', 'Drums', 'Violin', 'Ukulele'],
  'dance_instructor': [
    'Salsa',
    'Bachata',
    'Zumba',
    'Tango',
    'Contemporary',
    'Hip-Hop',
  ],
  'mechanic': ['Car', 'Motorcycle', 'Bicycle', 'Electric Vehicle'],
  'maintenance_tech': ['Pools', 'AC / HVAC', 'Gates & Doors', 'Appliances'],
  'personal_trainer': [
    'Strength Training',
    'CrossFit',
    'HIIT',
    'Boxing',
    'Swimming',
    'Calisthenics',
  ],
  'chef': [
    'Mexican Cuisine',
    'Italian',
    'Asian Fusion',
    'Vegan / Plant-Based',
    'BBQ / Grill',
    'Pastry & Baking',
  ],
  'photographer': [
    'Family',
    'Events',
    'Real Estate',
    'Portrait',
    'Product',
    'Wedding',
  ],
  'beauty': ['Hair Styling', 'Makeup', 'Nails', 'Facial Treatments', 'Bridal'],
  'bartender': [
    'Cocktails',
    'Wine Service',
    'Mixology Classes',
    'Event Bar Setup',
  ],
  'house_painter': ['Interior', 'Exterior', 'Decorative / Murals'],
  'graphic_designer': [
    'Flyers & Posters',
    'Menus',
    'Social Media',
    'Logos & Branding',
    'Web Design',
  ],
  'it_support': [
    'Computer Repair',
    'Phone Repair',
    'Network Setup',
    'Software Installation',
    'Data Recovery',
  ],
  'yoga': ['Hatha', 'Vinyasa', 'Ashtanga', 'Yin', 'Kundalini', 'Prenatal'],
  'scuba_instructor': [
    'Discover Scuba (Intro)',
    'Open Water Diver (OWD)',
    'Advanced Open Water (AOWD)',
    'Rescue Diver',
    'Master Scuba Diver',
    'Divemaster (DM)',
    'Deep Diving Specialty',
    'Night Diving',
    'Nitrox / Enriched Air',
    'Wreck Diving',
  ],
  'surf_instructor': [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Longboard',
    'Shortboard',
    'Stand-Up Paddle',
  ],
  'snorkeling_guide': [
    'Reef Tours',
    'Night Snorkeling',
    'Free Diving Intro',
    'Marine Biology Education',
  ],
  'sailing_instructor': [
    'Day Sailing',
    'Overnight Charters',
    'ASA Certification',
    'Racing',
  ],
  'fishing_guide': [
    'Deep Sea',
    'Fly Fishing',
    'Shore Fishing',
    'Catch & Release',
    'Spearfishing',
  ],
};

String serviceCategoryLabel(String? value) {
  if (value == null) return '';
  for (final item in serviceCategories) {
    if (item.value == value) return item.label;
  }
  return value;
}

List<ServiceCategory> serviceCategoriesInGroup(String group) {
  return serviceCategories.where((c) => c.group == group).toList();
}

List<String> skillsForService(String? value) {
  if (value == null) return const [];
  return serviceSubspecialties[value] ?? const [];
}
