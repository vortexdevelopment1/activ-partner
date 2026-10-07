import { randomUUID } from 'crypto';

import {
  PartnerServiceQuestionType as QuestionType,
  type PrismaClient,
} from '../../generated/prisma/client';
import { toCategorySlug } from './categories.seed';

const PLAYING_ENV_OPTIONS = [
  'Indoor',
  'Outdoor',
  'Air Conditioned',
  'Covered',
  'Floodlights',
  'Spectator Seating',
];
const COACHING_OPTIONS = [
  'Beginner',
  'Intermediate',
  'Advanced',
  'Kids',
  'Personal',
];
const RECOMMENDED_FOR_OPTIONS = [
  'Beginners',
  'Casual',
  'Competitive',
  'Kids',
  'Corporate',
];

const ACTIVITY_CONFIG: Record<string, [string, string]> = {
  'Pickle Ball': ['Total Courts', 'Court Surface'],
  Padel: ['Total Courts', 'Court Surface'],
  'Table Tennis': ['Total Tables', 'Table Quality'],
  Badminton: ['Total Courts', 'Court Surface'],
  Tennis: ['Total Courts', 'Court Surface'],
  Squash: ['Total Courts', 'Court Surface'],
  Hockey: ['Total Fields', 'Field Type'],
  Basketball: ['Total Courts', 'Court Type'],
  'Football Turf': ['Total Turfs', 'Turf Type'],
  Teqball: ['Total Tables', 'Table Quality'],
  Volleyball: ['Total Courts', 'Court Surface'],
  Frisbee: ['Field Size (m)', 'Field Surface'],
  'Cricket Nets': ['Total Nets', 'Pitch Type'],
  'Cricket Turf': ['Total Turfs', 'Pitch Type'],
  'Box Cricket': ['Total Arenas', 'Pitch Surface'],
  Pilates: ['Max Class Size', 'Studio Type'],
  Gym: ['Gym Area (sqft)', 'Gym Type'],
  HIIT: ['Max Class Size', 'Workout Type'],
  Crossfit: ['Max Class Size', 'Box Type'],
  'Dance Fitness': ['Max Class Size', 'Dance Style'],
  Yoga: ['Max Class Size', 'Yoga Style'],
  'Martial Arts': ['Training Mats', 'Martial Art Type'],
  MMA: ['Cages/Rings', 'Training Type'],
  Boxing: ['Rings', 'Ring Type'],
  Swimming: ['Pool Length (m)', 'Pool Type'],
  Skating: ['Rink Size', 'Rink Type'],
  Trampoline: ['Trampolines', 'Trampoline Type'],
  Billiards: ['Tables', 'Table Type'],
  Bowling: ['Lanes', 'Lane Type'],
  Shooting: ['Lanes', 'Range Type'],
  Archery: ['Targets', 'Range Type'],
  Bouldering: ['Wall Height (m)', 'Wall Type'],
  'Rock Climbing': ['Wall Height (m)', 'Wall Type'],
  Equestrian: ['Horses Available', 'Arena Type'],
  Paintball: ['Fields', 'Field Type'],
  'Adventure Sports': ['Activities Offered', 'Adventure Type'],
  'Other Activity': ['Max Participants', 'Activity Category'],
};

const buildQuestions = (
  serviceCategoryId: string,
  capacityLabel: string,
  typeLabel: string,
  activityName: string,
) => {
  const now = new Date();
  const definitions = activityName === 'Basketball' ? [
    ['Activity Description', QuestionType.TEXTAREA, true, []],
    ['Total Arenas', QuestionType.NUMBER, false, []],
    ['Total Courts', QuestionType.NUMBER, false, []],
    ['Pitch Surface', QuestionType.SELECT, false, ['Wooden', 'Synthetic', 'Concrete', 'Rubber']],
    ['Court Type', QuestionType.SELECT, false, ['Full Court', 'Half Court']],
    ['Playing Environment', QuestionType.MULTISELECT, false, PLAYING_ENV_OPTIONS],
    ['Equipment Available', QuestionType.MULTISELECT, false, []],
    ['Coaching Available', QuestionType.MULTISELECT, false, COACHING_OPTIONS],
    ['Recommended For', QuestionType.MULTISELECT, false, RECOMMENDED_FOR_OPTIONS],
  ] as const : [
    ['Activity Description', QuestionType.TEXTAREA, true, []],
    [capacityLabel, QuestionType.NUMBER, false, []],
    [typeLabel, QuestionType.SELECT, false, []],
    ['Playing Environment', QuestionType.MULTISELECT, false, PLAYING_ENV_OPTIONS],
    ['Equipment Available', QuestionType.MULTISELECT, false, []],
    ['Coaching Available', QuestionType.MULTISELECT, false, COACHING_OPTIONS],
    ['Recommended For', QuestionType.MULTISELECT, false, RECOMMENDED_FOR_OPTIONS],
  ] as const;

  return definitions.map(([question, type, isRequired, options], index) => ({
    id: randomUUID(),
    service_category_id: serviceCategoryId,
    question,
    type,
    options: [...options],
    is_required: isRequired,
    sort_order: index + 1,
    updated_at: now,
  }));
};

export async function seedQuestions(prisma: PrismaClient, activityNames?: readonly string[]) {
  let inserted = 0;
  let skipped = 0;

  for (const [activityName, [capacityLabel, typeLabel]] of Object.entries(
    ACTIVITY_CONFIG,
  )) {
    if (activityNames && !activityNames.includes(activityName)) continue;
    const category = await prisma.partner_service_categories.findUnique({
      where: { slug: toCategorySlug(activityName) },
    });

    if (!category) {
      console.log(`Category missing, questions skipped: ${activityName}`);
      continue;
    }

    const existingCount = await prisma.partner_service_questions.count({
      where: { service_category_id: category.id },
    });

    if (existingCount > 0 && activityName !== 'Basketball') {
      skipped++;
      continue;
    }

    const definitions = buildQuestions(category.id, capacityLabel, typeLabel, activityName);
    const existing = existingCount > 0
      ? await prisma.partner_service_questions.findMany({ where: { service_category_id: category.id } })
      : [];
    const missing = [];
    for (const definition of definitions) {
      const question = existing.find((item) => item.question.trim().toLowerCase() === definition.question.toLowerCase());
      if (!question) {
        missing.push(definition);
      } else {
        await prisma.partner_service_questions.update({
          where: { id: question.id },
          data: {
            sort_order: definition.sort_order,
            ...((!Array.isArray(question.options) || question.options.length === 0) && definition.options.length > 0
              ? { options: definition.options } : {}),
          },
        });
      }
    }
    const result = missing.length > 0
      ? await prisma.partner_service_questions.createMany({ data: missing })
      : { count: 0 };
    inserted += result.count;
  }

  console.log(`Questions inserted: ${inserted}; categories skipped: ${skipped}`);
}
