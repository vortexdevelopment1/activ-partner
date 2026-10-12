const activityLogos: [string[], string][] = [
  [['pickleball', 'pickle ball'], 'pickleball'],
  [['table tennis', 'ping pong'], 'table-tennis'],
  [['padel'], 'padel'],
  [['badminton'], 'badminton'],
  [['tennis'], 'tennis'],
  [['squash'], 'squash'],
  [['basketball'], 'basketball'],
  [['volleyball'], 'volleyball'],
  [['teqball'], 'teqball'],
  [['football', 'soccer'], 'football'],
  [['hockey'], 'hockey'],
  [['cricket nets'], 'cricket-nets'],
  [['cricket'], 'cricket'],
  [['billiard', 'snooker'], 'billiards'],
  [['bowling'], 'bowling'],
  [['swim'], 'swimming'],
  [['skating'], 'skating'],
  [['trampoline'], 'trampoline'],
  [['archery', 'shooting'], 'archery'],
  [['bouldering', 'climbing'], 'climbing'],
  [['equestrian', 'horse'], 'equestrian'],
  [['adventure', 'paintball'], 'adventure'],
  [['frisbee'], 'frisbee'],
  [['yoga', 'pilates'], 'yoga'],
  [['dance'], 'dance'],
  [['martial'], 'martial-arts'],
  [['mma'], 'mma'],
  [['boxing'], 'boxing'],
  [['gym'], 'gym'],
  [['hiit', 'crossfit', 'fitness'], 'fitness'],
  [['cardio'], 'cardio'],
  [['diving'], 'diving'],
  [['kids', 'playground'], 'playground'],
  [['arcade'], 'arcade'],
  [['arts', 'craft'], 'arts'],
];

export function activityLogoUrl(name: string): string {
  const label = name.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
  const logo = activityLogos.find(([aliases]) => aliases.some((alias) => label.includes(alias)))?.[1]
    ?? (label === 'pool' ? 'swimming' : label === 'court' ? 'badminton' : 'other');
  return `${import.meta.env.BASE_URL}activities/${logo}.png`;
}
