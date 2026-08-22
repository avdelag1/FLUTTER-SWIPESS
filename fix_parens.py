with open('lib/src/features/dashboard/presentation/widgets/dashboard_dock.dart', 'r') as f:
    text = f.read()

text = text.replace("""              ),
            ),
    );
  }
}""", """              ),
            ),
          ),
        ),
      ),
    );
  }
}""")

with open('lib/src/features/dashboard/presentation/widgets/dashboard_dock.dart', 'w') as f:
    f.write(text)
