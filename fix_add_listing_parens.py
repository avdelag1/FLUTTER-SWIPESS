with open('lib/src/features/add/presentation/screens/add_listing_screen.dart', 'r') as f:
    text = f.read()

# I erroneously replaced:
#         ],
#       ),
#     );
#   }
# }
# class _StepChooser
#
# Let's find where I added the extra parenthesis and remove it.
# And add the proper two parenthesis at the end of the `build` method for AddListingScreen.

text = text.replace('''        ],
      ),
      ),
    );
  }
}

class _StepChooser''', '''        ],
      ),
    );
  }
}

class _StepChooser''')

text = text.replace('''            ),
          ),
        ],
      ),
    );
  }

  Future<void> _next(ListingDraft draft) async {''', '''            ),
          ),
        ],
      ),
      ),
      ),
    );
  }

  Future<void> _next(ListingDraft draft) async {''')

with open('lib/src/features/add/presentation/screens/add_listing_screen.dart', 'w') as f:
    f.write(text)
