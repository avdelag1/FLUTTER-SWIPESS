import re

with open('lib/src/features/add/presentation/screens/add_listing_screen.dart', 'r') as f:
    text = f.read()

# Replace return ColoredBox( ... with return Scaffold( backgroundColor: AppTheme.dashBg, body: SafeArea( child: Column( ...
text = text.replace('''    return ColoredBox(
      color: AppTheme.dashBg,
      child: Column(''', '''    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      body: SafeArea(
        child: Column(''')

# We need to add an extra closing parenthesis at the end of the build method for AddListingScreen.
# The AddListingScreen build method ends right before class _StepChooser.
# Let's replace '        ],\n      ),\n    );\n  }\n}\n\nclass _StepChooser' with '        ],\n      ),\n    );\n    );\n  }\n}\n\nclass _StepChooser'
text = text.replace('''        ],
      ),
    );
  }
}

class _StepChooser''', '''        ],
      ),
      ),
    );
  }
}

class _StepChooser''')

with open('lib/src/features/add/presentation/screens/add_listing_screen.dart', 'w') as f:
    f.write(text)
