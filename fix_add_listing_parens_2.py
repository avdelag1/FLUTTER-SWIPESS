with open('lib/src/features/add/presentation/screens/add_listing_screen.dart', 'r') as f:
    text = f.read()

text = text.replace('''            ),
          ),
        ],
      ),
      ),
      ),
    );
  }

  Future<void> _next(ListingDraft draft) async {''', '''            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _next(ListingDraft draft) async {''')

with open('lib/src/features/add/presentation/screens/add_listing_screen.dart', 'w') as f:
    f.write(text)
