import { randomUUID } from "crypto";

import {
  PartnerServiceQuestionType as QT,
  type PrismaClient,
} from "../../generated/prisma/client";
import { toCategorySlug } from "./categories.seed";

// ─── Option sets ──────────────────────────────────────────────────────────────
const YES_NO = ["Yes", "No"];
const INDOOR_OUTDOOR = ["Indoor", "Outdoor"];
const PLAYING_ENV = [
  "Indoor",
  "Outdoor",
  "Air Conditioned",
  "Covered",
  "Floodlights",
  "Spectator Seating",
];
const COACHING = ["Beginner", "Intermediate", "Advanced", "Kids", "Personal"];
const RECOMMENDED = ["Beginners", "Casual", "Competitive", "Kids", "Corporate"];

// ─── Field definition type ───────────────────────────────────────────────────
type FieldDef = {
  question: string;
  type: QT;
  required?: boolean;
  options?: string[];
  unit?: string;
  placeholder?: string;
  helperText?: string;
  minLength?: number;
  maxLength?: number;
};

// ─── Per-activity field definitions (from client Excel sheet) ────────────────
export const ACTIVITY_FIELDS: Record<string, FieldDef[]> = {
  // ── Single Booking ──────────────────────────────────────────────────────────
  Gym: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder:
        "Our gym offers a range of strength and cardio equipment for people with different fitness goals. Members can work out independently, follow their own training plans, and ask our team about available guidance. Suitable for beginners and experienced fitness enthusiasts.",
      maxLength: 150,
    },
    { question: "Total Floor Area", type: QT.NUMBER, unit: "sq ft" },
    { question: "Max Capacity", type: QT.NUMBER_STEPPER },
    { question: "Equipment Categories", type: QT.TEXT },
    { question: "Trainer Availability", type: QT.SELECT, options: YES_NO },
    { question: "Ventilation Type", type: QT.TEXT },
    { question: "Locker & Shower", type: QT.SELECT, options: YES_NO },
    { question: "Peak Hours", type: QT.TEXT },
  ],
  "Yoga Studio": [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder:
        "Our yoga studio offers a calm space to stretch, move, and improve balance and flexibility. Sessions may include guided breathing, relaxation, and yoga practices for different experience levels.",
      maxLength: 150,
    },
    { question: "Studio Area Size", type: QT.NUMBER, unit: "sq ft" },
    { question: "Max Batch Size", type: QT.NUMBER_STEPPER },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Floor Type", type: QT.TEXT },
    { question: "Instructor Availability", type: QT.SELECT, options: YES_NO },
  ],
  Pilates: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Studio Area Size", type: QT.NUMBER, unit: "sq ft" },
    { question: "Max Batch Size", type: QT.NUMBER_STEPPER },
    { question: "Equipment Provided", type: QT.TEXT },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Instructor Availability", type: QT.SELECT, options: YES_NO },
  ],
  Zumba: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Studio Area Size", type: QT.NUMBER, unit: "sq ft" },
    { question: "Max Batch Size", type: QT.NUMBER_STEPPER },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Instructor Availability", type: QT.SELECT, options: YES_NO },
  ],
  "Dance Studio": [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Studio Area Size", type: QT.NUMBER, unit: "sq ft" },
    { question: "Max Batch Size", type: QT.NUMBER_STEPPER },
    { question: "Dance Styles Offered", type: QT.TEXT },
    { question: "Floor Type", type: QT.TEXT },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Instructor Availability", type: QT.SELECT, options: YES_NO },
  ],
  CrossFit: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Box Area Size", type: QT.NUMBER, unit: "sq ft" },
    { question: "Max Batch Size", type: QT.NUMBER_STEPPER },
    { question: "Equipment Available", type: QT.TEXT },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Coach Availability", type: QT.SELECT, options: YES_NO },
  ],
  "HIIT Studio": [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Studio Area Size", type: QT.NUMBER, unit: "sq ft" },
    { question: "Max Batch Size", type: QT.NUMBER_STEPPER },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Instructor Availability", type: QT.SELECT, options: YES_NO },
  ],
  Bowling: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Lanes", type: QT.NUMBER_STEPPER },
    { question: "Lane Type", type: QT.TEXT },
    { question: "Shoe Rental Available", type: QT.SELECT, options: YES_NO },
    { question: "Food & Beverage Available", type: QT.SELECT, options: YES_NO },
  ],
  Trampoline: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Trampolines", type: QT.NUMBER_STEPPER },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Safety Nets Available", type: QT.SELECT, options: YES_NO },
    { question: "Age Restriction", type: QT.TEXT },
  ],
  "Adventure Sports": [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder:
        "Our adventure sports venue offers activity experiences for visitors looking for something active and different. Please review the specific activity options, safety briefing, equipment provision, and booking conditions before visiting.",
      maxLength: 150,
    },
    { question: "Activity Sub-Type", type: QT.TEXT, placeholder: "Zipline" },
    {
      question: "Safety Equipment",
      type: QT.TEXT,
      placeholder: "Helmet, harness",
    },
    { question: "Instructor Present", type: QT.TEXT, placeholder: "Yes" },
    { question: "Age Restriction", type: QT.TEXT, placeholder: "10+" },
  ],
  "Rock Climbing": [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Wall Height", type: QT.NUMBER, unit: "meters" },
    { question: "Max Climbers", type: QT.NUMBER_STEPPER },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Equipment Provided", type: QT.SELECT, options: YES_NO },
    { question: "Instructor Available", type: QT.SELECT, options: YES_NO },
  ],
  Bouldering: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Wall Height", type: QT.NUMBER, unit: "meters" },
    { question: "Max Climbers", type: QT.NUMBER_STEPPER },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Equipment Provided", type: QT.SELECT, options: YES_NO },
    { question: "Instructor Available", type: QT.SELECT, options: YES_NO },
  ],
  Boxing: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Rings", type: QT.NUMBER_STEPPER },
    { question: "Ring Type", type: QT.TEXT },
    { question: "Gloves & Gear Provided", type: QT.SELECT, options: YES_NO },
    { question: "Coach Availability", type: QT.SELECT, options: YES_NO },
  ],
  MMA: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Cages/Rings", type: QT.NUMBER_STEPPER },
    { question: "Training Type", type: QT.TEXT },
    { question: "Equipment Provided", type: QT.SELECT, options: YES_NO },
    { question: "Coach Availability", type: QT.SELECT, options: YES_NO },
  ],
  "Martial Arts": [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Training Area Size", type: QT.NUMBER, unit: "sq ft" },
    { question: "Max Batch Size", type: QT.NUMBER_STEPPER },
    { question: "Martial Art Styles", type: QT.TEXT },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Instructor Availability", type: QT.SELECT, options: YES_NO },
  ],
  Archery: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Targets/Lanes", type: QT.NUMBER_STEPPER },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Equipment Provided", type: QT.SELECT, options: YES_NO },
    { question: "Instructor Available", type: QT.SELECT, options: YES_NO },
  ],
  Shooting: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Lanes", type: QT.NUMBER_STEPPER },
    { question: "Range Type", type: QT.TEXT },
    { question: "Equipment Provided", type: QT.SELECT, options: YES_NO },
    { question: "Safety Briefing Provided", type: QT.SELECT, options: YES_NO },
  ],
  Swimming: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Pool Length", type: QT.NUMBER, unit: "meters" },
    { question: "Total Lanes", type: QT.NUMBER_STEPPER },
    { question: "Pool Type", type: QT.TEXT },
    { question: "Lifeguard Available", type: QT.SELECT, options: YES_NO },
    { question: "Coaching Available", type: QT.SELECT, options: YES_NO },
  ],
  Skating: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Rink Area Size", type: QT.NUMBER, unit: "sq ft" },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Skate Rental Available", type: QT.SELECT, options: YES_NO },
    { question: "Instructor Available", type: QT.SELECT, options: YES_NO },
  ],
  Equestrian: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Horses Available", type: QT.NUMBER_STEPPER },
    { question: "Arena Type", type: QT.TEXT },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Instructor Available", type: QT.SELECT, options: YES_NO },
  ],
  Paintball: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Fields", type: QT.NUMBER_STEPPER },
    {
      question: "Playing Environment",
      type: QT.CHECKBOX,
      options: PLAYING_ENV,
    },
    { question: "Equipment Provided", type: QT.SELECT, options: YES_NO },
    { question: "Min Team Size", type: QT.NUMBER },
  ],
  Frisbee: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Field Area", type: QT.NUMBER, unit: "sq ft" },
    {
      question: "Playing Environment",
      type: QT.CHECKBOX,
      options: PLAYING_ENV,
    },
    { question: "Equipment Provided", type: QT.SELECT, options: YES_NO },
  ],
  // ── Court Booking ───────────────────────────────────────────────────────────
  Badminton: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Courts", type: QT.NUMBER_STEPPER },
    {
      question: "Playing Environment",
      type: QT.CHECKBOX,
      options: PLAYING_ENV,
    },
    { question: "Shuttle Provided", type: QT.SELECT, options: YES_NO },
    { question: "Court Surface", type: QT.TEXT },
    { question: "Coaching Available", type: QT.SELECT, options: YES_NO },
  ],
  Tennis: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Courts", type: QT.NUMBER_STEPPER },
    {
      question: "Playing Environment",
      type: QT.CHECKBOX,
      options: PLAYING_ENV,
    },
    { question: "Racket & Ball Provided", type: QT.SELECT, options: YES_NO },
    { question: "Court Surface", type: QT.TEXT },
    { question: "Coaching Available", type: QT.SELECT, options: YES_NO },
  ],
  Pickleball: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Courts", type: QT.NUMBER_STEPPER },
    {
      question: "Playing Environment",
      type: QT.CHECKBOX,
      options: PLAYING_ENV,
    },
    { question: "Paddle & Ball Provided", type: QT.SELECT, options: YES_NO },
    { question: "Court Surface", type: QT.TEXT },
    { question: "Coaching Available", type: QT.SELECT, options: YES_NO },
  ],
  Padel: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Courts", type: QT.NUMBER_STEPPER },
    {
      question: "Playing Environment",
      type: QT.CHECKBOX,
      options: PLAYING_ENV,
    },
    { question: "Racket & Ball Provided", type: QT.SELECT, options: YES_NO },
    { question: "Court Surface", type: QT.TEXT },
    { question: "Coaching Available", type: QT.SELECT, options: YES_NO },
  ],
  Squash: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Courts", type: QT.NUMBER_STEPPER },
    {
      question: "Playing Environment",
      type: QT.CHECKBOX,
      options: PLAYING_ENV,
    },
    { question: "Racket & Ball Provided", type: QT.SELECT, options: YES_NO },
    { question: "Court Surface", type: QT.TEXT },
    { question: "Coaching Available", type: QT.SELECT, options: YES_NO },
  ],
  Basketball: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Courts", type: QT.NUMBER_STEPPER },
    {
      question: "Court Type",
      type: QT.SELECT,
      options: ["Full Court", "Half Court"],
    },
    {
      question: "Playing Environment",
      type: QT.CHECKBOX,
      options: PLAYING_ENV,
    },
    { question: "Ball Provided", type: QT.SELECT, options: YES_NO },
    { question: "Court Surface", type: QT.TEXT },
  ],
  Volleyball: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Courts", type: QT.NUMBER_STEPPER },
    {
      question: "Playing Environment",
      type: QT.CHECKBOX,
      options: PLAYING_ENV,
    },
    { question: "Ball Provided", type: QT.SELECT, options: YES_NO },
    { question: "Court Surface", type: QT.TEXT },
    { question: "Net Provided", type: QT.SELECT, options: YES_NO },
  ],
  Padbol: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Courts", type: QT.NUMBER_STEPPER },
    {
      question: "Playing Environment",
      type: QT.CHECKBOX,
      options: PLAYING_ENV,
    },
    { question: "Equipment Provided", type: QT.SELECT, options: YES_NO },
    { question: "Court Surface", type: QT.TEXT },
  ],

  // ── Table Booking ───────────────────────────────────────────────────────────
  "Table Tennis": [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Tables", type: QT.NUMBER_STEPPER },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Bat & Ball Provided", type: QT.SELECT, options: YES_NO },
    { question: "Table Quality", type: QT.TEXT },
  ],
  "Pool Table": [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Tables", type: QT.NUMBER_STEPPER },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Cue & Ball Provided", type: QT.SELECT, options: YES_NO },
    { question: "Table Quality", type: QT.TEXT },
  ],
  Snooker: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Tables", type: QT.NUMBER_STEPPER },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Cue & Ball Provided", type: QT.SELECT, options: YES_NO },
    { question: "Table Quality", type: QT.TEXT },
  ],
  Teqball: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Tables", type: QT.NUMBER_STEPPER },
    { question: "Indoor/Outdoor", type: QT.RADIO, options: INDOOR_OUTDOOR },
    { question: "Ball Provided", type: QT.SELECT, options: YES_NO },
  ],

  // ── Turf Booking ────────────────────────────────────────────────────────────
  "Cricket Turf": [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Turfs", type: QT.NUMBER_STEPPER },
    {
      question: "Playing Environment",
      type: QT.CHECKBOX,
      options: PLAYING_ENV,
    },
    {
      question: "Pitch Type",
      type: QT.SELECT,
      options: ["Natural Turf", "Artificial Turf", "Matting", "Concrete"],
    },
    { question: "Equipment Provided", type: QT.SELECT, options: YES_NO },
    { question: "Floodlights Available", type: QT.SELECT, options: YES_NO },
  ],
  "Football Turf": [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Turfs", type: QT.NUMBER_STEPPER },
    { question: "Turf Area", type: QT.NUMBER, unit: "sq ft" },
    {
      question: "Playing Environment",
      type: QT.CHECKBOX,
      options: PLAYING_ENV,
    },
    { question: "Turf Type", type: QT.TEXT },
    { question: "Ball Provided", type: QT.SELECT, options: YES_NO },
    { question: "Floodlights Available", type: QT.SELECT, options: YES_NO },
  ],
  Hockey: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Fields", type: QT.NUMBER_STEPPER },
    {
      question: "Playing Environment",
      type: QT.CHECKBOX,
      options: PLAYING_ENV,
    },
    { question: "Field Type", type: QT.TEXT },
    { question: "Equipment Provided", type: QT.SELECT, options: YES_NO },
    { question: "Floodlights Available", type: QT.SELECT, options: YES_NO },
  ],
  // ── Cricket Nets ─────────────────────────────────────────────────────────────
  "Cricket Nets": [
    { question: "Activity Description", type: QT.TEXTAREA, required: true },
    { question: "Total Nets", type: QT.NUMBER_STEPPER },
    {
      question: "Playing Environment",
      type: QT.CHECKBOX,
      options: PLAYING_ENV,
    },
    {
      question: "Pitch Type",
      type: QT.SELECT,
      options: ["Natural Turf", "Artificial Turf", "Matting", "Concrete"],
    },
    { question: "Equipment Provided", type: QT.SELECT, options: YES_NO },
    { question: "Bowling Machine Available", type: QT.SELECT, options: YES_NO },
    { question: "Coach Available", type: QT.SELECT, options: YES_NO },
  ],
};

// ─── Seed function ────────────────────────────────────────────────────────────
export async function seedActivityDetailFields(prisma: PrismaClient) {
  let inserted = 0;
  let updated = 0;

  for (const [activityName, fields] of Object.entries(ACTIVITY_FIELDS)) {
    const slug = toCategorySlug(activityName);
    const category = await prisma.partner_service_categories.findUnique({
      where: { slug },
    });

    if (!category) {
      console.log(
        `  [SKIP] Category not found for: ${activityName} (slug: ${slug})`,
      );
      continue;
    }

    const existing = await prisma.partner_service_questions.findMany({
      where: { service_category_id: category.id },
    });

    const now = new Date();

    for (let i = 0; i < fields.length; i++) {
      const field = fields[i];
      const sort_order = i + 1;
      const match = existing.find(
        (q) => q.question.trim().toLowerCase() === field.question.toLowerCase(),
      );

      if (match) {
        // Update type, options, unit, sort_order
        await prisma.partner_service_questions.update({
          where: { id: match.id },
          data: {
            type: field.type,
            options: field.options ?? [],
            unit: field.unit ?? null,
            placeholder: field.placeholder ?? null,
            helper_text: field.helperText ?? null,
            min_length: field.minLength ?? null,
            max_length: field.maxLength ?? null,
            is_required: field.required ?? false,
            sort_order,
            updated_at: now,
          },
        });
        updated++;
      } else {
        await prisma.partner_service_questions.create({
          data: {
            id: randomUUID(),
            service_category_id: category.id,
            question: field.question,
            type: field.type,
            options: field.options ?? [],
            unit: field.unit ?? null,
            placeholder: field.placeholder ?? null,
            helper_text: field.helperText ?? null,
            min_length: field.minLength ?? null,
            max_length: field.maxLength ?? null,
            is_required: field.required ?? false,
            sort_order,
            updated_at: now,
          },
        });
        inserted++;
      }
    }

    // Delete questions not part of the activity specification
    const fieldNamesLower = fields.map((f) => f.question.trim().toLowerCase());
    const stale = existing.filter(
      (q) => !fieldNamesLower.includes(q.question.trim().toLowerCase()),
    );
    if (stale.length > 0) {
      await prisma.partner_service_questions.deleteMany({
        where: { id: { in: stale.map((s) => s.id) } },
      });
      console.log(
        `  [CLEAN] Removed ${stale.length} obsolete questions for ${activityName}`,
      );
    }

    console.log(`  [OK] ${activityName}: ${fields.length} fields processed`);
  }

  console.log(
    `Activity detail fields — inserted: ${inserted}; updated: ${updated}`,
  );
}
