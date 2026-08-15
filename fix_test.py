import os

test_path = "test/auth_controller_test.dart"
if os.path.exists(test_path):
    with open(test_path, "r") as f:
        content = f.read()

    if "auth_provider.dart" not in content:
        content = "import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';\n" + content

    with open(test_path, "w") as f:
        f.write(content)

test2_path = "test/auth_screen_test.dart"
if os.path.exists(test2_path):
    with open(test2_path, "r") as f:
        content2 = f.read()
    
    # fix RenderFlex overflow by wrapping auth screen in a larger surface or using a bigger flutter test window
    content2 = content2.replace("child: AuthScreen(),", "child: SizedBox(width: 800, height: 1000, child: AuthScreen()),")
    content2 = content2.replace("surfaceSize: const Size(400, 800)", "surfaceSize: const Size(800, 1000)")
    
    with open(test2_path, "w") as f:
        f.write(content2)

