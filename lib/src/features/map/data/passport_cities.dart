/// Cap `PASSPORT_QUICK_CITIES` with unique cover photos.
class PassportCity {
  const PassportCity({
    required this.name,
    required this.country,
    required this.lat,
    required this.lng,
    required this.photoUrl,
  });

  final String name;
  final String country;
  final double lat;
  final double lng;
  final String photoUrl;

  String get label => '$name, $country';
}

const _u = 'https://images.unsplash.com';

abstract final class PassportCities {
  static const hub = PassportCity(
    name: 'Tulum',
    country: 'Mexico',
    lat: 20.2114,
    lng: -87.4654,
    photoUrl:
        '$_u/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=600&q=80',
  );

  static const all = <PassportCity>[
    PassportCity(
      name: 'Miami',
      country: 'United States',
      lat: 25.7617,
      lng: -80.1918,
      photoUrl:
          '$_u/photo-1535498730771-e7358ce8e819?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Medellín',
      country: 'Colombia',
      lat: 6.2442,
      lng: -75.5812,
      photoUrl:
          '$_u/photo-1587595431973-160d0d94add1?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Tulum',
      country: 'Mexico',
      lat: 20.2114,
      lng: -87.4654,
      photoUrl:
          '$_u/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Cancún',
      country: 'Mexico',
      lat: 21.1619,
      lng: -86.8515,
      photoUrl:
          '$_u/photo-1510097161878-b897312d7e00?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Cabo',
      country: 'Mexico',
      lat: 22.8905,
      lng: -109.9167,
      photoUrl:
          '$_u/photo-1518509562904-e7ef99b04389?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Cartagena',
      country: 'Colombia',
      lat: 10.3910,
      lng: -75.4794,
      photoUrl:
          '$_u/photo-1536098561742-ca998e48cbcc?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Dubai',
      country: 'UAE',
      lat: 25.2048,
      lng: 55.2708,
      photoUrl:
          '$_u/photo-1512453979798-5eaef8b271b3?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Marrakech',
      country: 'Morocco',
      lat: 31.6295,
      lng: -7.9811,
      photoUrl:
          '$_u/photo-1597212618440-806262de4f6b?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Paris',
      country: 'France',
      lat: 48.8566,
      lng: 2.3522,
      photoUrl:
          '$_u/photo-1511739001486-6bfe10ce785f?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'London',
      country: 'United Kingdom',
      lat: 51.5074,
      lng: -0.1278,
      photoUrl:
          '$_u/photo-1513635269975-59663e0ac1ad?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Rome',
      country: 'Italy',
      lat: 41.9028,
      lng: 12.4964,
      photoUrl:
          '$_u/photo-1552832230-c0197dd311b5?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Barcelona',
      country: 'Spain',
      lat: 41.3851,
      lng: 2.1734,
      photoUrl:
          '$_u/photo-1583422409516-2895a77efded?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Ibiza',
      country: 'Spain',
      lat: 38.9067,
      lng: 1.4206,
      photoUrl:
          '$_u/photo-1630347197970-fc4bf0d0334a?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Mykonos',
      country: 'Greece',
      lat: 37.4467,
      lng: 25.3289,
      photoUrl:
          '$_u/photo-1533104816931-20faadf52775?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Santorini',
      country: 'Greece',
      lat: 36.3932,
      lng: 25.4615,
      photoUrl:
          '$_u/photo-1570077188670-e3a8d69ac5ff?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Monaco',
      country: 'Monaco',
      lat: 43.7384,
      lng: 7.4246,
      photoUrl:
          '$_u/photo-1595138320174-a64d168e9970?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'New York',
      country: 'United States',
      lat: 40.7128,
      lng: -74.0060,
      photoUrl:
          '$_u/photo-1541336032412-2048a678540d?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'LA',
      country: 'United States',
      lat: 34.0522,
      lng: -118.2437,
      photoUrl:
          '$_u/photo-1580655653885-65763b2597d0?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Las Vegas',
      country: 'United States',
      lat: 36.1699,
      lng: -115.1398,
      photoUrl:
          '$_u/photo-1581351721010-8cf859cb14a4?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Tokyo',
      country: 'Japan',
      lat: 35.6762,
      lng: 139.6503,
      photoUrl:
          '$_u/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Seoul',
      country: 'South Korea',
      lat: 37.5665,
      lng: 126.9780,
      photoUrl:
          '$_u/photo-1538485399081-7c8ce5af0c3c?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Bali',
      country: 'Indonesia',
      lat: -8.4095,
      lng: 115.1889,
      photoUrl:
          '$_u/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Singapore',
      country: 'Singapore',
      lat: 1.3521,
      lng: 103.8198,
      photoUrl:
          '$_u/photo-1525625293386-3f8f99389edd?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Bangkok',
      country: 'Thailand',
      lat: 13.7563,
      lng: 100.5018,
      photoUrl:
          '$_u/photo-1563492065599-3520f775eeed?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Sydney',
      country: 'Australia',
      lat: -33.8688,
      lng: 151.2093,
      photoUrl:
          '$_u/photo-1506973035872-a4ec16b8e8d9?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Rio',
      country: 'Brazil',
      lat: -22.9068,
      lng: -43.1729,
      photoUrl:
          '$_u/photo-1483729558449-99ef09a8c325?auto=format&fit=crop&w=600&q=80',
    ),
    PassportCity(
      name: 'Punta Cana',
      country: 'Dominican Republic',
      lat: 18.5601,
      lng: -68.3725,
      photoUrl:
          '$_u/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=600&q=80',
    ),
  ];
}
