String activityLogoAsset(String name, {String? category}) {
  final label = (category?.trim().isNotEmpty == true ? category! : name)
      .toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  final compact = label.replaceAll(' ', '');
  String logo = 'other';
  if (compact.contains('pickleball')) {
    logo = 'pickleball';
  } else if (label.contains('table tennis') || label.contains('ping pong')) {
    logo = 'table-tennis';
  } else if (label.contains('padel')) {
    logo = 'padel';
  } else if (label.contains('badminton') || label == 'court') {
    logo = 'badminton';
  } else if (label.contains('tennis')) {
    logo = 'tennis';
  } else if (label.contains('squash')) {
    logo = 'squash';
  } else if (label.contains('basketball')) {
    logo = 'basketball';
  } else if (label.contains('volleyball')) {
    logo = 'volleyball';
  } else if (label.contains('teqball')) {
    logo = 'teqball';
  } else if (label.contains('football') || label.contains('soccer')) {
    logo = 'football';
  } else if (label.contains('hockey')) {
    logo = 'hockey';
  } else if (label.contains('cricket nets')) {
    logo = 'cricket-nets';
  } else if (label.contains('cricket')) {
    logo = 'cricket';
  } else if (label.contains('billiard') || label.contains('snooker')) {
    logo = 'billiards';
  } else if (label.contains('bowling')) {
    logo = 'bowling';
  } else if (label.contains('swim') || label == 'pool') {
    logo = 'swimming';
  } else if (label.contains('skating')) {
    logo = 'skating';
  } else if (label.contains('trampoline')) {
    logo = 'trampoline';
  } else if (label.contains('archery') || label.contains('shooting')) {
    logo = 'archery';
  } else if (label.contains('bouldering') || label.contains('climbing')) {
    logo = 'climbing';
  } else if (label.contains('equestrian') || label.contains('horse')) {
    logo = 'equestrian';
  } else if (label.contains('adventure') || label.contains('paintball')) {
    logo = 'adventure';
  } else if (label.contains('frisbee')) {
    logo = 'frisbee';
  } else if (label.contains('yoga') || label.contains('pilates')) {
    logo = 'yoga';
  } else if (label.contains('dance')) {
    logo = 'dance';
  } else if (label.contains('martial')) {
    logo = 'martial-arts';
  } else if (label.contains('mma')) {
    logo = 'mma';
  } else if (label.contains('boxing')) {
    logo = 'boxing';
  } else if (label.contains('gym')) {
    logo = 'gym';
  } else if (label.contains('hiit') || label.contains('crossfit') || label.contains('fitness')) {
    logo = 'fitness';
  } else if (label.contains('cardio')) {
    logo = 'cardio';
  } else if (label.contains('diving')) {
    logo = 'diving';
  } else if (label.contains('kids') || label.contains('playground')) {
    logo = 'playground';
  } else if (label.contains('arcade')) {
    logo = 'arcade';
  } else if (label.contains('arts') || label.contains('craft')) {
    logo = 'arts';
  }
  return 'assets/activities/$logo.png';
}
