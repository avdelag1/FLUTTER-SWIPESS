/// Chip taxonomies ported from Capacitor `listingTaxonomies.ts`.
/// Users pick chips instead of typing freeform listing copy.
class ListingTaxonomies {
  static const adjectives = [
    'Amazing', 'Beautiful', 'Gorgeous', 'Pretty', 'Nice', 'Cool',
    'Incredible', 'Wonderful', 'Cute', 'Charming', 'Cozy', 'Stylish',
    'Modern', 'Bright', 'Sunny', 'Stunning', 'Elegant', 'Luxurious',
    'Exuberant', 'Peaceful',
  ];

  static const sizes = [
    'Tiny', 'Small', 'Medium', 'Spacious', 'Large', 'Big', 'Huge',
    'Enormous', 'Giant',
  ];

  static const bedroomCounts = ['Studio', '1', '2', '3', '4', '5', '6+'];
  static const bathroomCounts = ['1', '1.5', '2', '2.5', '3', '3.5', '4+'];

  static const propertyVibe = [
    'Quiet', 'Lively', 'Family-friendly', 'Pet-friendly',
    'Beachfront', 'Jungle', 'Downtown', 'Gated', 'Eco',
  ];

  static const propertyFeatures = [
    'Private Pool', 'Shared Pool', 'Gym', 'Parking', 'Garage', 'Carport',
    'AC', 'WiFi', 'Security 24/7', 'Garden', 'Balcony', 'Terrace',
    'Rooftop', 'Elevator', 'Workspace', 'Sea View', 'Mountain View',
    'Hot Tub', 'Outdoor Kitchen', 'BBQ', 'Furnished',
  ];

  static const propertyIncluded = [
    'Water', 'Electricity', 'Gas', 'Internet',
    'Cleaning', 'Maintenance', 'Trash', 'Cable TV',
  ];

  static const propertyRules = [
    'No smoking', 'No parties', 'Quiet hours',
    'Pets allowed', 'Children welcome', 'Long-stay only',
  ];

  static const propertyTypes = [
    'Penthouse', 'House', 'Apartment', 'Loft', 'Studio',
    'Mobile Home', 'Camper / RV', 'Land', 'Building', 'Glamping',
    'Bungalow', 'Room', 'Commercial',
  ];

  static const rentalDurations = ['3 months', '6 months', '1 year'];

  static const popularCountries = [
    'Mexico', 'United States', 'Canada', 'France', 'Spain', 'Italy',
    'United Kingdom', 'Germany', 'Argentina', 'Colombia',
  ];

  static const popularCities = [
    'Tulum', 'Playa del Carmen', 'Cancún', 'Mexico City', 'Guadalajara',
    'Monterrey', 'Mérida', 'Querétaro', 'Miami', 'Los Angeles',
    'New York City', 'Austin', 'Barcelona', 'Madrid', 'Lisbon',
  ];

  static const motoTypes = [
    'Sport', 'Cruiser', 'Adventure', 'Naked',
    'Scooter', 'Off-road', 'Touring', 'Electric',
  ];

  static const motoConditions = [
    'Brand new', 'Like new', 'Good', 'Fair', 'Project',
  ];

  static const motoFeatures = [
    'ABS', 'ESC', 'Traction control', 'Heated grips',
    'Luggage rack', 'Crash bars', 'Quick-shifter', 'Bluetooth',
  ];

  static const motoIncluded = [
    'Helmet', 'Riding gear', 'Lock', 'Top case',
    'Charger', 'Insurance', 'Roadside assistance',
  ];

  static const motoBrands = [
    'Yamaha', 'Honda', 'Kawasaki', 'Suzuki', 'BMW', 'Ducati', 'KTM',
    'Harley-Davidson', 'Triumph', 'Vespa',
  ];

  static const bikeTypes = [
    'Road', 'Mountain', 'Hybrid', 'Cruiser',
    'BMX', 'Folding', 'Cargo', 'Electric',
  ];

  static const bikeFeatures = [
    'Front suspension', 'Full suspension', 'Disc brakes',
    'Carbon frame', 'Aluminum frame', 'Tubeless', 'Dropper post',
  ];

  static const bikeIncluded = [
    'Lock', 'Lights', 'Basket', 'Pump', 'Helmet', 'Repair kit',
  ];

  static const bikeConditions = ['Brand new', 'Like new', 'Good', 'Fair'];
  static const bikeFrameSizes = ['XS', 'S', 'M', 'L', 'XL'];
  static const bikeBrands = [
    'Specialized', 'Trek', 'Giant', 'Cannondale', 'Santa Cruz',
    'Canyon', 'Rad Power', 'Aventon',
  ];

  static const yachtTypes = [
    'Sailboat', 'Catamaran', 'Motor yacht', 'Gulet',
    'Speedboat', 'Trawler', 'Pontoon', 'Houseboat',
  ];

  static const yachtConditions = [
    'Brand new', 'Like new', 'Good', 'Fair', 'Project',
  ];

  static const yachtFeatures = [
    'Air conditioning', 'WiFi', 'Flybridge', 'Watermaker',
    'Tender', 'Stabilizers', 'Solar panels', 'Bow thruster',
    'GPS / Chartplotter', 'Autopilot', 'Sun deck', 'Jacuzzi',
  ];

  static const yachtIncluded = [
    'Captain', 'Crew', 'Fuel', 'Insurance',
    'Snorkel gear', 'Paddleboard', 'Dinghy', 'Safety equipment',
  ];

  static const yachtBrands = [
    'Beneteau', 'Jeanneau', 'Lagoon', 'Azimut', 'Sunseeker',
    'Princess', 'Sea Ray', 'Yamaha',
  ];

  static const workerTraits = [
    'Punctual', 'Detail-oriented', 'English-speaking', 'Spanish-speaking',
    'Insured', 'Background-checked', 'Own tools', 'Own vehicle',
    'Emergency available',
  ];

  static const workerAvailability = [
    'Mornings', 'Afternoons', 'Evenings', 'Weekends', '24/7',
  ];

  static const workerPricing = [
    'Hourly', 'Daily', 'Per-job', 'Monthly contract',
  ];

  static const languages = [
    'English', 'Spanish', 'French', 'German',
    'Italian', 'Portuguese', 'Russian', 'Mandarin',
  ];

  static String joinChips(Iterable<String> parts) {
    return parts.where((p) => p.trim().isNotEmpty).join(' · ');
  }

  static String conditionSlug(String? label) {
    switch (label) {
      case 'Brand new':
      case 'Like new':
        return 'excellent';
      case 'Good':
        return 'good';
      case 'Fair':
        return 'fair';
      case 'Project':
        return 'poor';
      default:
        return (label ?? '').toLowerCase();
    }
  }
}
