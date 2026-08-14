import 'package:flutter/material.dart';

/// Cap `SeekerRequestDialog` WORKER_CATEGORIES — seeker post taxonomy.
class SeekerWorkerCategory {
  const SeekerWorkerCategory({
    required this.id,
    required this.label,
    required this.subcategories,
    this.color = const Color(0xFFFF4D00),
    this.icon = Icons.work_rounded,
  });

  final String id;
  final String label;
  final List<String> subcategories;
  final Color color;
  final IconData icon;
}

Color seekerCategoryColor(String? id) {
  for (final c in seekerWorkerCategories) {
    if (c.id == id) return c.color;
  }
  return const Color(0xFFFF4D00);
}

const seekerWorkerCategories = <SeekerWorkerCategory>[
  SeekerWorkerCategory(
    id: 'cleaning',
    label: 'Cleaning',
    color: Color(0xFF3B82F6),
    icon: Icons.cleaning_services_rounded,
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
    color: Color(0xFF06B6D4),
    icon: Icons.plumbing_rounded,
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
    color: Color(0xFFF59E0B),
    icon: Icons.bolt_rounded,
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
    color: Color(0xFF10B981),
    icon: Icons.directions_car_rounded,
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
    color: Color(0xFFFF4D00),
    icon: Icons.restaurant_rounded,
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
    color: Color(0xFF22C55E),
    icon: Icons.yard_rounded,
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
    color: Color(0xFF8B5CF6),
    icon: Icons.handyman_rounded,
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
    color: Color(0xFFEB4898),
    icon: Icons.child_care_rounded,
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
    color: Color(0xFFE4007C),
    icon: Icons.fitness_center_rounded,
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
    color: Color(0xFFA78BFA),
    icon: Icons.spa_rounded,
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
    color: Color(0xFF6366F1),
    icon: Icons.local_shipping_rounded,
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
    color: Color(0xFF0EA5E9),
    icon: Icons.memory_rounded,
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
    color: Color(0xFFF97316),
    icon: Icons.format_paint_rounded,
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
    color: Color(0xFF64748B),
    icon: Icons.shield_rounded,
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
    color: Color(0xFFFF8C42),
    icon: Icons.more_horiz_rounded,
    subcategories: ['Describe your need below'],
  ),
];
