import 'dart:io';

void main() {
  var repoFile = File('lib/src/features/subscriptions/data/subscription_repository.dart');
  var content = repoFile.readAsStringSync();
  
  var ifNullStr = '''
      if (row == null) return null;''';
  var newIfNullStr = '''
      if (row == null) {
        final createdAt = DateTime.tryParse(user.createdAt)?.toUtc();
        if (createdAt != null) return _addCalendarMonths(createdAt, 3);
        return null;
      }''';
      
  content = content.replaceAll(ifNullStr, newIfNullStr);
  repoFile.writeAsStringSync(content);
}
