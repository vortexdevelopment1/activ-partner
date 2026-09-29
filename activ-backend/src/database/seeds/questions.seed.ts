import { DataSource } from 'typeorm';
import { Question } from '../../modules/questions/entities/question.entity';
import { Category } from '../../modules/categories/entities/category.entity';
import { QuestionType } from '../../common/enums/question-type.enum';

const PLAYING_ENV_OPTIONS = [
  'Indoor', 'Outdoor', 'Air Conditioned', 'Covered', 'Floodlights', 'Spectator Seating',
];
const COACHING_OPTIONS = ['Beginner', 'Intermediate', 'Advanced', 'Kids', 'Personal'];
const RECOMMENDED_FOR_OPTIONS = ['Beginners', 'Casual', 'Competitive', 'Kids', 'Corporate'];

// Per-activity labels for Q2 (capacity metric) and Q3 (type/quality dropdown)
const ACTIVITY_CONFIG: Record<string, { capacityLabel: string; typeLabel: string }> = {
  'Pickle Ball':       { capacityLabel: 'Total Courts',       typeLabel: 'Court Surface' },
  'Padel':             { capacityLabel: 'Total Courts',       typeLabel: 'Court Surface' },
  'Table Tennis':      { capacityLabel: 'Total Tables',       typeLabel: 'Table Quality' },
  'Badminton':         { capacityLabel: 'Total Courts',       typeLabel: 'Court Surface' },
  'Tennis':            { capacityLabel: 'Total Courts',       typeLabel: 'Court Surface' },
  'Squash':            { capacityLabel: 'Total Courts',       typeLabel: 'Court Surface' },
  'Hockey':            { capacityLabel: 'Total Fields',       typeLabel: 'Field Type' },
  'Basketball':        { capacityLabel: 'Total Courts',       typeLabel: 'Court Type' },
  'Football Turf':     { capacityLabel: 'Total Turfs',        typeLabel: 'Turf Type' },
  'Teqball':           { capacityLabel: 'Total Tables',       typeLabel: 'Table Quality' },
  'Volleyball':        { capacityLabel: 'Total Courts',       typeLabel: 'Court Surface' },
  'Frisbee':           { capacityLabel: 'Field Size (m)',     typeLabel: 'Field Surface' },
  'Cricket Nets':      { capacityLabel: 'Total Nets',         typeLabel: 'Pitch Type' },
  'Cricket Turf':      { capacityLabel: 'Total Turfs',        typeLabel: 'Pitch Type' },
  'Box Cricket':       { capacityLabel: 'Total Arenas',       typeLabel: 'Pitch Surface' },
  'Pilates':           { capacityLabel: 'Max Class Size',     typeLabel: 'Studio Type' },
  'Gym':               { capacityLabel: 'Gym Area (sqft)',    typeLabel: 'Gym Type' },
  'HIIT':              { capacityLabel: 'Max Class Size',     typeLabel: 'Workout Type' },
  'Crossfit':          { capacityLabel: 'Max Class Size',     typeLabel: 'Box Type' },
  'Dance Fitness':     { capacityLabel: 'Max Class Size',     typeLabel: 'Dance Style' },
  'Yoga':              { capacityLabel: 'Max Class Size',     typeLabel: 'Yoga Style' },
  'Martial Arts':      { capacityLabel: 'Training Mats',      typeLabel: 'Martial Art Type' },
  'MMA':               { capacityLabel: 'Cages/Rings',        typeLabel: 'Training Type' },
  'Boxing':            { capacityLabel: 'Rings',              typeLabel: 'Ring Type' },
  'Swimming':          { capacityLabel: 'Pool Length (m)',    typeLabel: 'Pool Type' },
  'Skating':           { capacityLabel: 'Rink Size',          typeLabel: 'Rink Type' },
  'Trampoline':        { capacityLabel: 'Trampolines',        typeLabel: 'Trampoline Type' },
  'Billiards':         { capacityLabel: 'Tables',             typeLabel: 'Table Type' },
  'Bowling':           { capacityLabel: 'Lanes',              typeLabel: 'Lane Type' },
  'Shooting':          { capacityLabel: 'Lanes',              typeLabel: 'Range Type' },
  'Archery':           { capacityLabel: 'Targets',            typeLabel: 'Range Type' },
  'Bouldering':        { capacityLabel: 'Wall Height (m)',    typeLabel: 'Wall Type' },
  'Rock Climbing':     { capacityLabel: 'Wall Height (m)',    typeLabel: 'Wall Type' },
  'Equestrian':        { capacityLabel: 'Horses Available',   typeLabel: 'Arena Type' },
  'Paintball':         { capacityLabel: 'Fields',             typeLabel: 'Field Type' },
  'Adventure Sports':  { capacityLabel: 'Activities Offered', typeLabel: 'Adventure Type' },
  'Other Activity':    { capacityLabel: 'Max Participants',   typeLabel: 'Activity Category' },
};

function buildQuestions(categoryId: string, config: { capacityLabel: string; typeLabel: string }): Partial<Question>[] {
  return [
    {
      categoryId,
      questionText: 'Activity Description',
      questionType: QuestionType.TEXTAREA,
      isRequired: true,
      isActive: true,
      order: 1,
      placeholder: 'Describe this activity...',
      options: null,
    },
    {
      categoryId,
      questionText: config.capacityLabel,
      questionType: QuestionType.NUMBER,
      isRequired: false,
      isActive: true,
      order: 2,
      options: null,
    },
    {
      categoryId,
      questionText: config.typeLabel,
      questionType: QuestionType.SELECT,
      isRequired: false,
      isActive: true,
      order: 3,
      // Options are activity-specific and not defined in the sheet — add via admin panel
      options: null,
    },
    {
      categoryId,
      questionText: 'Playing Environment',
      questionType: QuestionType.MULTISELECT,
      isRequired: false,
      isActive: true,
      order: 4,
      options: PLAYING_ENV_OPTIONS,
    },
    {
      categoryId,
      questionText: 'Equipment Available',
      questionType: QuestionType.MULTISELECT,
      isRequired: false,
      isActive: true,
      order: 5,
      // Options vary by facility — add via admin panel after seeding
      options: null,
    },
    {
      categoryId,
      questionText: 'Coaching Available',
      questionType: QuestionType.MULTISELECT,
      isRequired: false,
      isActive: true,
      order: 6,
      options: COACHING_OPTIONS,
    },
    {
      categoryId,
      questionText: 'Recommended For',
      questionType: QuestionType.MULTISELECT,
      isRequired: false,
      isActive: true,
      order: 7,
      options: RECOMMENDED_FOR_OPTIONS,
    },
  ];
}

export async function seedQuestions(dataSource: DataSource) {
  const questionRepo = dataSource.getRepository(Question);
  const categoryRepo = dataSource.getRepository(Category);

  let created = 0;
  let skipped = 0;
  let missing = 0;

  for (const [activityName, config] of Object.entries(ACTIVITY_CONFIG)) {
    // Find category by name (case-insensitive)
    const category = await categoryRepo
      .createQueryBuilder('c')
      .where('LOWER(c.name) = LOWER(:name)', { name: activityName })
      .getOne();

    if (!category) {
      console.log(`  ⚠️  Category not found in DB: "${activityName}" — skipping`);
      missing++;
      continue;
    }

    // Skip if this category already has questions
    const existingCount = await questionRepo.count({
      where: { categoryId: category.id },
    });

    if (existingCount > 0) {
      console.log(`  ℹ️  "${activityName}" already has ${existingCount} question(s) — skipping`);
      skipped++;
      continue;
    }

    const questions = buildQuestions(category.id, config).map((q) =>
      questionRepo.create(q),
    );
    await questionRepo.save(questions);
    console.log(`  ✅ "${activityName}" — inserted ${questions.length} questions`);
    created += questions.length;
  }

  console.log(`\n📊 Questions seed summary:`);
  console.log(`   Inserted : ${created} questions`);
  console.log(`   Skipped  : ${skipped} categories (already had questions)`);
  console.log(`   Missing  : ${missing} categories (not found in DB)`);
}
