import re

with open('lib/src/features/map/presentation/screens/real_mapbox_screen.dart', 'r') as f:
    text = f.read()

print("Listing has city?" , "listing.city" in text)
