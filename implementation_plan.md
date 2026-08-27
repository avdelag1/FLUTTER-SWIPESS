# Map Redesign

The map UI will be redesigned to match the provided mockups while retaining the existing "glowing dock" bottom navigation.

## Proposed Changes

### `lib/src/features/map/presentation/screens/real_mapbox_screen.dart`
- **Top Bar**:
  - Add a white circular hamburger menu button on the top left. (Tapping it will pop the map to return to the dashboard, preserving current navigation flow).
  - Add a black "SWIPESS" title in the top center.
  - Add a white circular search button on the top right.
- **Filter Chips**:
  - Add a horizontally scrolling list of filter chips below the top bar (All, Events, Properties, Services).
  - These chips will update a local state `_activeCategory` which will filter the `_visiblePins()`.
- **Map Pins**:
  - Redesign `_buildMarkerIcon` to draw the teardrop style pins from the mockup.
  - Use colors matching the mockup based on category (Purple for events, Teal for properties, Pink/Orange for services).
- **Bottom Cards Area**:
  - Add a white bottom sheet container that pops up from the bottom.
  - Include a title "Discover [City]" and a horizontally scrolling list of cards corresponding to the visible map pins.
  - When a pin is tapped on the map, the list will scroll to that specific card, or a specific single card will pop up like in the first screenshot.

## Verification Plan
- Launch the app and open the map.
- Verify the top bar matches the mockup design.
- Verify the teardrop pins render correctly.
- Verify the bottom sheet displays the cards and that the filter chips correctly filter both the map pins and the bottom cards.
