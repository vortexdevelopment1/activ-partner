bool isPlaceholderActivityQuestion(Object? label) =>
    const {'abcd', 'abcde', 'asdf2'}
        .contains(label?.toString().trim().toLowerCase());
