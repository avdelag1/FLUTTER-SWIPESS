/// Cap `SeekerRequestDialog` WORKER_CATEGORIES — seeker post taxonomy.
class SeekerWorkerCategory {
  const SeekerWorkerCategory({
    required this.id,
    required this.label,
    required this.subcategories,
  });

  final String id;
  final String label;
  final List<String> subcategories;
}

const seekerWorkerCategories = <SeekerWorkerCategory>[
  SeekerWorkerCategory(
    id: 'cleaning',
    label: 'Cleaning',
    subcategories: [
      'Regular cleaning',
      'Deep cleaning',
      'Move-in/out',
      'Office cleaning',
      'Post-construction',
    ],
  ),
  SeekerWorkerCategory(
    id: 'plumbing',
    label: 'Plumbing',
    subcategories: [
      'Leak repair',
      'Pipe installation',
      'Drain unclog',
      'Water heater',
      'Bathroom work',
    ],
  ),
  SeekerWorkerCategory(
    id: 'electrical',
    label: 'Electrical',
    subcategories: [
      'Outlet/switch',
      'Lighting install',
      'Circuit breaker',
      'Wiring',
      'Generator',
    ],
  ),
  SeekerWorkerCategory(
    id: 'driving',
    label: 'Driver',
    subcategories: [
      'Airport transfer',
      'Daily driver',
      'Event chauffeur',
      'Errands',
      'Moving items',
    ],
  ),
  SeekerWorkerCategory(
    id: 'chef',
    label: 'Chef',
    subcategories: [
      'Private dinner',
      'Meal prep',
      'Party catering',
      'Cooking classes',
      'Special diet',
    ],
  ),
  SeekerWorkerCategory(
    id: 'gardening',
    label: 'Gardening',
    subcategories: [
      'Lawn mowing',
      'Landscaping',
      'Tree trimming',
      'Garden design',
      'Irrigation',
    ],
  ),
  SeekerWorkerCategory(
    id: 'handyman',
    label: 'Handyman',
    subcategories: [
      'Furniture assembly',
      'Wall mounting',
      'Door/lock repair',
      'Tile repair',
      'General repairs',
    ],
  ),
  SeekerWorkerCategory(
    id: 'childcare',
    label: 'Childcare',
    subcategories: [
      'Full-time nanny',
      'Babysitter',
      'After-school care',
      'Weekend coverage',
      'Newborn',
    ],
  ),
  SeekerWorkerCategory(
    id: 'fitness',
    label: 'Fitness',
    subcategories: [
      'Personal training',
      'Group fitness',
      'Yoga',
      'Nutrition coaching',
      'Sports',
    ],
  ),
  SeekerWorkerCategory(
    id: 'massage',
    label: 'Massage',
    subcategories: [
      'Swedish',
      'Deep tissue',
      'Sports massage',
      'Couples massage',
      'Prenatal',
    ],
  ),
  SeekerWorkerCategory(
    id: 'moving',
    label: 'Moving',
    subcategories: [
      'Full move',
      'Partial move',
      'Packing help',
      'Loading/unloading',
      'Rearranging',
    ],
  ),
  SeekerWorkerCategory(
    id: 'tech',
    label: 'Tech / IT',
    subcategories: [
      'Computer repair',
      'Network setup',
      'Smart home',
      'Phone repair',
      'Software help',
    ],
  ),
  SeekerWorkerCategory(
    id: 'painting',
    label: 'Painting',
    subcategories: [
      'Interior',
      'Exterior',
      'Murals/decorative',
      'Furniture refinishing',
      'Touch-ups',
    ],
  ),
  SeekerWorkerCategory(
    id: 'security',
    label: 'Security',
    subcategories: [
      'Security guard',
      'CCTV install',
      'Home security',
      'Event security',
      'Night watch',
    ],
  ),
  SeekerWorkerCategory(
    id: 'other',
    label: 'Other',
    subcategories: ['Describe your need below'],
  ),
];
