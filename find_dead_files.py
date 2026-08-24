import os
import re

def find_all_dart_files(root):
    files = []
    for dirpath, _, filenames in os.walk(root):
        for f in filenames:
            if f.endswith('.dart'):
                files.append(os.path.join(dirpath, f))
    return files

def get_import_paths(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    # match conditional imports like:
    # import '...' if (...) '...';
    # just grab ALL string literals that end in .dart
    matches = re.findall(r"['\"]([^'\"]+\.dart)['\"]", content)
    return matches

root_dir = 'lib'
all_files = find_all_dart_files(root_dir)

used_basenames = set()
for f in all_files:
    imports = get_import_paths(f)
    for imp in imports:
        used_basenames.add(os.path.basename(imp))

dead_files = []
for f in all_files:
    basename = os.path.basename(f)
    if basename not in used_basenames and basename != 'main.dart':
        dead_files.append(f)

for df in sorted(dead_files):
    print(df)
