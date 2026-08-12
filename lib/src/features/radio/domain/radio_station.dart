/// Curated SomaFM / public streams matching Capacitor World Radio vibes.
class RadioStation {
  const RadioStation({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.city,
    required this.genre,
  });

  final String id;
  final String name;
  final String streamUrl;
  final String city;
  final String genre;
}

const kRadioStations = <RadioStation>[
  RadioStation(
    id: 'miami-chill',
    name: 'Chill Miami',
    streamUrl: 'https://ice1.somafm.com/groovesalad-128-mp3',
    city: 'Miami',
    genre: 'Chillout',
  ),
  RadioStation(
    id: 'miami-lush',
    name: 'Miami Vibes',
    streamUrl: 'https://ice1.somafm.com/lush-128-mp3',
    city: 'Miami',
    genre: 'Downtempo',
  ),
  RadioStation(
    id: 'miami-trip',
    name: 'Ocean Drive',
    streamUrl: 'https://ice1.somafm.com/thetrip-128-mp3',
    city: 'Miami',
    genre: 'House',
  ),
  RadioStation(
    id: 'tulum-drone',
    name: 'Tulum Drone Zone',
    streamUrl: 'https://ice1.somafm.com/dronezone-128-mp3',
    city: 'Tulum',
    genre: 'Ambient',
  ),
  RadioStation(
    id: 'ibiza-beat',
    name: 'Ibiza Beat Blender',
    streamUrl: 'https://ice1.somafm.com/beatblender-128-mp3',
    city: 'Ibiza',
    genre: 'Lounge',
  ),
  RadioStation(
    id: 'ny-secret',
    name: 'Secret Agent',
    streamUrl: 'https://ice1.somafm.com/secretagent-128-mp3',
    city: 'New York',
    genre: 'Retro',
  ),
  RadioStation(
    id: 'cali-80s',
    name: 'California 80s',
    streamUrl: 'https://ice1.somafm.com/u80s-128-mp3',
    city: 'California',
    genre: '80s Pop',
  ),
  RadioStation(
    id: 'london-sf',
    name: 'Space Station Soma',
    streamUrl: 'https://ice1.somafm.com/spacestation-128-mp3',
    city: 'London',
    genre: 'Electronica',
  ),
];
