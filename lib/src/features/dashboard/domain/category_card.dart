import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/constants/app_assets.dart';

class CategoryCardData {
  const CategoryCardData({
    required this.id,
    required this.label,
    required this.description,
    required this.photos,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final List<String> photos;
  final IconData icon;
}

const dashboardCategories = [
  CategoryCardData(
    id: 'property',
    label: 'Properties',
    description: 'Properties for rent and sale',
    photos: [AppAssets.filterProperty, AppAssets.filterPropertyJungle],
    icon: Icons.workspace_premium_outlined,
  ),
  CategoryCardData(
    id: 'pros',
    label: 'Pros',
    description: 'Find professional services',
    photos: [AppAssets.filterPros],
    icon: Icons.auto_awesome,
  ),
  CategoryCardData(
    id: 'motorcycle',
    label: 'Motorcycles',
    description: 'Motorcycles for rent and sale',
    photos: [AppAssets.filterMotorcycle],
    icon: Icons.local_fire_department_outlined,
  ),
  CategoryCardData(
    id: 'bicycle',
    label: 'Bicycles',
    description: 'Bicycles for rent and sale',
    photos: [AppAssets.filterBicycle, AppAssets.filterBicycleSunset],
    icon: Icons.bolt_rounded,
  ),
  CategoryCardData(
    id: 'buyers',
    label: 'Buyers',
    description: 'Purchase Ready',
    photos: [AppAssets.filterBuyers],
    icon: Icons.shopping_bag_outlined,
  ),
  CategoryCardData(
    id: 'renters',
    label: 'Renters',
    description: 'Looking to Move',
    photos: [AppAssets.filterRenters],
    icon: Icons.vpn_key_outlined,
  ),
  CategoryCardData(
    id: 'leads',
    label: 'Leads',
    description: 'People seeking your service',
    photos: [AppAssets.filterLeads],
    icon: Icons.groups_outlined,
  ),
];
