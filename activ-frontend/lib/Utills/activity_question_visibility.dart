bool isPlaceholderActivityQuestion(Object? label) =>
    const {'abcd', 'abcde', 'asdf2'}
        .contains(label?.toString().trim().toLowerCase());

bool isRemovedActivityQuestion(Object? label) =>
    label?.toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ==
    'equipment available';
