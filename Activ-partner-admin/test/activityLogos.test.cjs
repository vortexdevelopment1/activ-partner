const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');

const source = fs.readFileSync(path.join(__dirname, '../src/utils/activityLogos.ts'), 'utf8')
  .replace('import.meta.env.BASE_URL', "'/admin/'");
const output = {};
vm.runInNewContext(ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS },
}).outputText, { exports: output });

// Every category currently in the catalogue, including its existing Padel spelling.
const categories = {
  'Adventure Sports': 'adventure.svg', Archery: 'archery.png', Badminton: 'badminton.png',
  Basketball: 'basketball.png', Billiards: 'billiards.png', Bouldering: 'climbing.png',
  Bowling: 'bowling.png', 'Box Cricket': 'cricket.png', Boxing: 'boxing.png',
  'Cricket Nets': 'cricket-nets.svg', 'Cricket Turf': 'cricket.png', Crossfit: 'fitness.png',
  'Dance Fitness': 'dance.png', Equestrian: 'equestrian.png', 'Football Turf': 'football.png',
  Frisbee: 'frisbee.png', Gym: 'gym.png', HIIT: 'fitness.png', Hockey: 'hockey.png',
  'Martial Arts': 'martial-arts.png', MMA: 'mma.png', 'Other Activity': 'other.svg',
  Padelll: 'padel.png', Paintball: 'paintball.png', 'Pickle Ball': 'pickleball.png',
  Pilates: 'pilates.svg', 'Rock Climbing': 'climbing.png', Shooting: 'shooting.svg',
  Skating: 'skating.png', Squash: 'squash.svg', Swimming: 'swimming.png',
  'Table Tennis': 'table-tennis.png', Tennis: 'tennis.png', Teqball: 'teqball.svg',
  Trampoline: 'trampoline.png', Volleyball: 'volleyball.png', Yoga: 'yoga.png',
  Diving: 'diving.svg', 'Arts & Crafts': 'arts.svg', 'Kids Play': 'kids-play.png',
};

for (const [name, file] of Object.entries(categories)) {
  test(`${name} uses ${file}, an existing category asset`, () => {
    assert.equal(output.activityLogoUrl(name), `/admin/activities/${file}`);
    assert(fs.existsSync(path.join(__dirname, '../public/activities', file)));
  });
}

test('unknown categories use the neutral activity image', () => {
  assert.equal(output.activityLogoUrl('New Category'), '/admin/activities/other.svg');
});

test('normalization preserves specific racket sports instead of matching generic tennis', () => {
  assert.equal(output.activityLogoUrl(' TABLE-TENNIS '), '/admin/activities/table-tennis.png');
  assert.equal(output.activityLogoUrl('TableTennis'), '/admin/activities/table-tennis.png');
  assert.equal(output.activityLogoUrl('Pickle-Ball'), '/admin/activities/pickleball.png');
});
