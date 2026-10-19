const activityLogos: [string[], string][] = [
  [['pickleball', 'pickle ball'], 'pickleball'],
  [['table tennis', 'tabletennis', 'ping pong'], 'table-tennis'],
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
  [['archery'], 'archery'],
  [['shooting'], 'shooting'],
  [['bouldering', 'climbing'], 'climbing'],
  [['equestrian', 'horse'], 'equestrian'],
  [['paintball'], 'paintball'],
  [['adventure'], 'adventure'],
  [['frisbee'], 'frisbee'],
  [['pilates'], 'pilates'],
  [['yoga'], 'yoga'],
  [['dance'], 'dance'],
  [['martial'], 'martial-arts'],
  [['mma'], 'mma'],
  [['boxing'], 'boxing'],
  [['gym'], 'gym'],
  [['hiit', 'crossfit', 'fitness'], 'fitness'],
  [['cardio'], 'cardio'],
  [['diving'], 'diving'],
  [['kids'], 'kids-play'],
  [['playground'], 'playground'],
  [['arcade'], 'arcade'],
  [['arts', 'craft'], 'arts'],
];

const vectorLogos = new Set(['adventure', 'arts', 'diving', 'pilates', 'shooting', 'squash', 'teqball', 'other', 'cricket-nets']);

export function activityLogoUrl(name: string): string {
  const label = name.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
  const logo = activityLogos.find(([aliases]) => aliases.some((alias) => label.includes(alias)))?.[1]
    ?? (label === 'pool' ? 'swimming' : label === 'court' ? 'badminton' : 'other');
  return `${import.meta.env.BASE_URL}activities/${logo}.${vectorLogos.has(logo) ? 'svg' : 'png'}`;
}
