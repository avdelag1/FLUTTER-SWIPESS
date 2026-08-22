with open('lib/src/features/dashboard/presentation/widgets/dashboard_dock.dart', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    new_lines.append(line)
    if line.strip() == '    );':
        break
new_lines.append('  }\n')
new_lines.append('}\n')
new_lines.append('\n')

with open('lib/src/features/dashboard/presentation/widgets/dashboard_dock.dart', 'w') as f:
    f.writelines(new_lines)
