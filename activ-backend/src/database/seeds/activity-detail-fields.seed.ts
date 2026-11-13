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
// ─── Per-activity field definitions (generated from approved Excel/Google Sheet) ────
export const ACTIVITY_FIELDS: Record<string, FieldDef[]> = {
  Gym: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our gym offers a range of strength and cardio equipment for people with different fitness goals. Members can work out independently, follow their own training plans, and ask our team about available guidance. Suitable for beginners and experienced fitness enthusiasts.",
      maxLength: 150,
    },
    {
      question: "Total Floor Area",
      type: QT.NUMBER,
      unit: "sq ft",
      placeholder: "5000 sq ft",
    },
    {
      question: "Max Capacity",
      type: QT.NUMBER_STEPPER,
      placeholder: "80 people",
    },
    {
      question: "Equipment Categories",
      type: QT.TEXT,
      placeholder: "Cardio, Strength, Free Weights",
    },
    {
      question: "Trainer Availability",
      type: QT.SELECT,
      options: ["Yes","No"],
      placeholder: "Yes or No",
    },
    {
      question: "Ventilation Type",
      type: QT.TEXT,
      placeholder: "Central AC",
    },
    {
      question: "Locker & Shower",
      type: QT.SELECT,
      options: ["Yes","No"],
      placeholder: "Yes or No",
    },
    {
      question: "Peak Hours",
      type: QT.TEXT,
      placeholder: "6–9 AM, 6–10 PM",
    },
  ],
  "Yoga Studio": [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our yoga studio offers a calm space to stretch, move, and improve balance and flexibility. Sessions may include guided breathing, relaxation, and yoga practices for different experience levels. It is a welcoming option for anyone looking to build a regular wellness routine.",
      maxLength: 150,
    },
    {
      question: "Studio Area Size",
      type: QT.NUMBER,
      unit: "sq ft",
      placeholder: "1200 sq ft",
    },
    {
      question: "Max Batch Size",
      type: QT.NUMBER_STEPPER,
      placeholder: "25 per batch",
    },
    {
      question: "Indoor/Outdoor",
      type: QT.TEXT,
      placeholder: "Indoor",
    },
    {
      question: "Floor Type",
      type: QT.TEXT,
      placeholder: "Wooden mat flooring",
    },
    {
      question: "Instructor Availability",
      type: QT.SELECT,
      options: ["Yes","No"],
      placeholder: "Yes or No",
    },
  ],
  Pilates: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our Pilates studio provides guided sessions focused on core strength, posture, control, and flexibility. Classes are designed to help participants move with awareness and practise at a suitable pace. Please ask us about available class formats and experience-level options.",
      maxLength: 150,
    },
    {
      question: "No. of Reformers",
      type: QT.NUMBER_STEPPER,
      placeholder: "6 reformers",
    },
    {
      question: "Batch Capacity",
      type: QT.NUMBER_STEPPER,
      placeholder: "6 people",
    },
    {
      question: "Certified Instructor",
      type: QT.SELECT,
      options: ["Yes","No"],
      placeholder: "Yes or No",
    },
    {
      question: "Studio Size",
      type: QT.NUMBER,
      unit: "sq ft",
      placeholder: "900 sq ft",
    },
  ],
  Zumba: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Join our energetic Zumba sessions combining dance-inspired movement with a fun workout. The classes are designed to keep you moving to music in a friendly group setting. Beginners are welcome, and you can check with us for the current schedule and class level.",
      maxLength: 150,
    },
    {
      question: "Max Batch Size",
      type: QT.NUMBER_STEPPER,
      placeholder: "40 people",
    },
    {
      question: "Sound System",
      type: QT.SELECT,
      options: ["Yes","No"],
      placeholder: "Yes or No",
    },
    {
      question: "Mirrors Available",
      type: QT.SELECT,
      options: ["Yes","No"],
      placeholder: "Yes or No",
    },
    {
      question: "Instructor Availability",
      type: QT.SELECT,
      options: ["Yes","No"],
      placeholder: "Yes or No",
    },
    {
      question: "Floor Type",
      type: QT.TEXT,
      placeholder: "Wooden",
    },
  ],
  "Dance Studio": [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our dance studio provides space to learn, practise, and enjoy dance in a supportive environment. Sessions may cover different dance styles and skill levels, depending on the class schedule. Whether you are starting out or polishing your moves, contact us to find a suitable session.",
      maxLength: 150,
    },
    {
      question: "Dance Styles",
      type: QT.TEXT,
      placeholder: "Hip-hop, Contemporary",
    },
    {
      question: "Studio Size",
      type: QT.NUMBER,
      unit: "sq ft",
      placeholder: "1500 sq ft",
    },
    {
      question: "Mirrors Available",
      type: QT.TEXT,
      placeholder: "Full wall mirrors",
    },
    {
      question: "Flooring Type",
      type: QT.TEXT,
      placeholder: "Wooden floor",
    },
    {
      question: "Batch Capacity",
      type: QT.NUMBER_STEPPER,
      placeholder: "30 people",
    },
    {
      question: "Instructor Available",
      type: QT.SELECT,
      options: ["Yes","No"],
      placeholder: "Yes or No",
    },
  ],
  CrossFit: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our CrossFit facility offers coached, workout-based training that can combine strength, conditioning, and functional movements. Sessions can be scaled to different fitness levels, with emphasis on technique and safe progression. Please check the schedule and coaching arrangements before booking.",
      maxLength: 150,
    },
    {
      question: "Box Area Size",
      type: QT.NUMBER,
      unit: "sq ft",
      placeholder: "4000 sq ft",
    },
    {
      question: "Max Class Capacity",
      type: QT.NUMBER_STEPPER,
      placeholder: "20 people",
    },
    {
      question: "Equipment Level",
      type: QT.TEXT,
      placeholder: "Advanced",
    },
    {
      question: "Certified Coach",
      type: QT.SELECT,
      options: ["Yes","No"],
      placeholder: "Yes or No",
    },
    {
      question: "Workout Type",
      type: QT.TEXT,
      placeholder: "WOD",
    },
  ],
  "HIIT Studio": [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our HIIT studio offers high-intensity interval training sessions that alternate periods of effort with recovery. Workouts may combine cardio, bodyweight exercises, and strength movements, with options adapted to different fitness levels. Check the timetable for the session best suited to you.",
      maxLength: 150,
    },
    {
      question: "Studio Size",
      type: QT.NUMBER,
      unit: "sq ft",
      placeholder: "1200 sq ft",
    },
    {
      question: "Max Participants",
      type: QT.NUMBER_STEPPER,
      placeholder: "25",
    },
    {
      question: "Equipment Provided",
      type: QT.TEXT,
      placeholder: "Kettlebells, ropes",
    },
    {
      question: "Trainer Availability",
      type: QT.SELECT,
      options: ["Yes","No"],
      placeholder: "Yes or No",
    },
  ],
  Badminton: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our badminton facility offers courts for friendly games, practice, and competitive play. Players can book a court with friends or use the space to improve their skills. Please check available court types, equipment rental, coaching, and session timings before booking.",
      maxLength: 150,
    },
    {
      question: "No. of Courts",
      type: QT.NUMBER_STEPPER,
      placeholder: "4 courts",
    },
    {
      question: "Indoor/Outdoor",
      type: QT.SELECT,
      options: ["Indoor","Outdoor"],
      placeholder: "Indoor",
    },
    {
      question: "Flooring Type",
      type: QT.TEXT,
      placeholder: "Synthetic",
    },
    {
      question: "Ceiling Height",
      type: QT.NUMBER,
      unit: "m",
      placeholder: "9 m",
    },
    {
      question: "Lighting Quality",
      type: QT.TEXT,
      placeholder: "LED lights",
    },
    {
      question: "Equipment Provided",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "8 players",
    },
  ],
  Tennis: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our tennis venue provides court space for practice, rallies, and matches with friends or training partners. Players can work on their technique and enjoy recreational or more competitive play. Check the available court surface, equipment options, coaching, and booking slots.",
      maxLength: 150,
    },
    {
      question: "No. of Courts",
      type: QT.NUMBER_STEPPER,
      placeholder: "2 courts",
    },
    {
      question: "Surface Type",
      type: QT.TEXT,
      placeholder: "Hard court",
    },
    {
      question: "Indoor/Outdoor",
      type: QT.SELECT,
      options: ["Indoor","Outdoor"],
      placeholder: "Indoor",
    },
    {
      question: "Lighting",
      type: QT.TEXT,
      placeholder: "Flood lights",
    },
    {
      question: "Ball Provided",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Coaching Available",
      type: QT.TEXT,
      placeholder: "Yes",
    },
  ],
  Pickleball: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our pickleball venue offers space to enjoy this fast-paced paddle sport, combining elements of tennis, badminton, and table tennis. It is suitable for social games as well as skill practice. Ask us about court availability, paddle rental, beginner support, and session timings.",
      maxLength: 150,
    },
    {
      question: "No. of Courts",
      type: QT.NUMBER_STEPPER,
      placeholder: "2 courts",
    },
    {
      question: "Surface Type",
      type: QT.TEXT,
      placeholder: "Concrete",
    },
    {
      question: "Indoor/Outdoor",
      type: QT.SELECT,
      options: ["Indoor","Outdoor"],
      placeholder: "Outdoor",
    },
    {
      question: "Paddle Provided",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Net Type",
      type: QT.TEXT,
      placeholder: "Standard",
    },
    {
      question: "Lighting",
      type: QT.TEXT,
      placeholder: "LED lights",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "4",
    },
  ],
  Padel: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our padel venue offers courts for doubles games, rallies, and friendly competition. The sport is easy to try with friends and offers plenty of opportunities to build coordination and tactics. Check with us for racket availability, coaching options, and current booking slots.",
      maxLength: 150,
    },
    {
      question: "No. of Courts",
      type: QT.NUMBER_STEPPER,
      placeholder: "2 court",
    },
    {
      question: "Court Type",
      type: QT.TEXT,
      placeholder: "Glass",
    },
    {
      question: "Indoor/Outdoor",
      type: QT.SELECT,
      options: ["Indoor","Outdoor"],
      placeholder: "Indoor",
    },
    {
      question: "Lighting",
      type: QT.TEXT,
      placeholder: "LED lights",
    },
    {
      question: "Equipment Provided",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "4",
    },
    {
      question: "Coach Availability",
      type: QT.SELECT,
      options: ["Yes","No"],
      placeholder: "Yes or No",
    },
  ],
  "Table Tennis": [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our table tennis facility provides tables for casual games, practice, and competitive rallies. Come with a friend or use a session to improve your control, speed, and consistency. Please check whether bats and balls are available and confirm the session duration before booking.",
      maxLength: 150,
    },
    {
      question: "No. of Tables",
      type: QT.NUMBER_STEPPER,
      placeholder: "6 tables",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "4",
    },
    {
      question: "Flooring Type",
      type: QT.TEXT,
      placeholder: "Wood",
    },
    {
      question: "Equipment Provided",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Lighting",
      type: QT.TEXT,
      placeholder: "LED lights",
    },
  ],
  Squash: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our squash venue offers court time for fast-paced rallies, fitness, and skill development. Players can book a game with a partner or practise their movement and shot-making. Check court availability, racket rental, coaching options, and any footwear requirements.",
      maxLength: 150,
    },
    {
      question: "No. of Courts",
      type: QT.NUMBER_STEPPER,
      placeholder: "2 courts",
    },
    {
      question: "Court Type",
      type: QT.TEXT,
      placeholder: "Glass-back",
    },
    {
      question: "Ceiling Height",
      type: QT.NUMBER,
      unit: "m",
      placeholder: "9 m",
    },
    {
      question: "Lighting",
      type: QT.TEXT,
      placeholder: "LED lights",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "2",
    },
    {
      question: "Coaching",
      type: QT.SELECT,
      options: ["Yes","No"],
      placeholder: "Yes or No",
    },
  ],
  "Cricket Turf": [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our cricket turf is a space for teams and groups to play practice matches and enjoy cricket together. Book a session for a friendly game, team activity, or skills practice. Please confirm the pitch format, session duration, equipment availability, and any team-size limits.",
      maxLength: 150,
    },
    {
      question: "No. of Turfs",
      type: QT.NUMBER_STEPPER,
      placeholder: "1 turf",
    },
    {
      question: "Pitch Type",
      type: QT.TEXT,
      placeholder: "Astro",
    },
    {
      question: "Lighting",
      type: QT.TEXT,
      placeholder: "Flood lights",
    },
    {
      question: "Equipment Provided",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "12",
    },
  ],
  "Football Turf": [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our football turf provides a dedicated playing area for friendly matches, team practice, and group games. Gather your team and book a slot to enjoy the game. Check the turf size, lighting, changing facilities, ball availability, and booking duration before your visit.",
      maxLength: 150,
    },
    {
      question: "No. of Grounds",
      type: QT.NUMBER_STEPPER,
      placeholder: "1 ground",
    },
    {
      question: "Turf Type",
      type: QT.TEXT,
      placeholder: "FIFA turf",
    },
    {
      question: "Match Format",
      type: QT.TEXT,
      placeholder: "5v5",
    },
    {
      question: "Lighting",
      type: QT.TEXT,
      placeholder: "Flood lights",
    },
    {
      question: "Goal Post Type",
      type: QT.TEXT,
      placeholder: "Standard",
    },
    {
      question: "Equipment Provided",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "10",
    },
  ],
  "Cricket Nets": [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our cricket nets provide a focused space for batting, bowling, and individual or team practice. Players can work on technique and consistency in a dedicated practice session. Please check the number and type of nets, equipment availability, coaching options, and slot duration.",
      maxLength: 150,
    },
    {
      question: "No. of Nets",
      type: QT.NUMBER_STEPPER,
      placeholder: "4 nets",
    },
    {
      question: "Pitch Type",
      type: QT.TEXT,
      placeholder: "Cement",
    },
    {
      question: "Bowling Machine",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Coach Available",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Safety Netting",
      type: QT.TEXT,
      placeholder: "Full net",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "4",
    },
  ],
  Basketball: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our basketball court is available for shooting practice, drills, pickup games, and team sessions. Players can work on their skills or enjoy a game with friends. Please check whether the court is indoor or outdoor, what equipment is provided, and how many players each booking accommodates.",
      maxLength: 150,
    },
    {
      question: "No. of Courts",
      type: QT.NUMBER_STEPPER,
      placeholder: "1 court",
    },
    {
      question: "Full/Half Court",
      type: QT.TEXT,
      placeholder: "Full",
    },
    {
      question: "Indoor/Outdoor",
      type: QT.TEXT,
      placeholder: "Outdoor",
    },
    {
      question: "Floor Type",
      type: QT.TEXT,
      placeholder: "Synthetic",
    },
    {
      question: "Lighting",
      type: QT.TEXT,
      placeholder: "Flood lights",
    },
    {
      question: "Ball Provided",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "10",
    },
  ],
  Volleyball: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our volleyball facility offers space for team games, practice, and recreational play. Bring your group to work on serves, passes, teamwork, and match play. Check the court surface, net setup, ball availability, and whether the session is suitable for your group size.",
      maxLength: 150,
    },
    {
      question: "No. of Courts",
      type: QT.NUMBER_STEPPER,
      placeholder: "1 court",
    },
    {
      question: "Indoor/Outdoor",
      type: QT.SELECT,
      options: ["Indoor","Outdoor"],
      placeholder: "Indoor",
    },
    {
      question: "Surface Type",
      type: QT.TEXT,
      placeholder: "Sand",
    },
    {
      question: "Net Quality",
      type: QT.TEXT,
      placeholder: "Professional",
    },
    {
      question: "Lighting",
      type: QT.TEXT,
      placeholder: "Flood lights",
    },
    {
      question: "Ball Provided",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "12",
    },
  ],
  Hockey: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our hockey facility provides space for training, drills, and team play, subject to the available playing surface and format. Players can practise their skills and coordinate with teammates in a dedicated session. Please confirm the surface type, permitted format, equipment requirements, and booking timings.",
      maxLength: 150,
    },
    {
      question: "No. of Grounds",
      type: QT.NUMBER_STEPPER,
      placeholder: "1 ground",
    },
    {
      question: "Turf Type",
      type: QT.TEXT,
      placeholder: "Astro",
    },
    {
      question: "Indoor/Outdoor",
      type: QT.SELECT,
      options: ["Indoor","Outdoor"],
      placeholder: "Outdoor",
    },
    {
      question: "Lighting",
      type: QT.TEXT,
      placeholder: "Flood lights",
    },
    {
      question: "Equipment Policy",
      type: QT.TEXT,
      placeholder: "Own gear",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "22",
    },
  ],
  Snooker: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our snooker venue offers tables for relaxed games, practice, and friendly competition. Enjoy a session with friends or focus on improving your accuracy and cue control. Check table availability, session duration, equipment provision, and any venue-specific playing rules.",
      maxLength: 150,
    },
    {
      question: "No. of Tables",
      type: QT.NUMBER_STEPPER,
      placeholder: "3 tables",
    },
    {
      question: "Table Type",
      type: QT.TEXT,
      placeholder: "Snooker",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "4",
    },
  ],
  Bowling: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our bowling venue offers an enjoyable activity for friends, families, and groups. Players can enjoy a casual game, practise their technique, or organise a group outing. Please check lane availability, shoe arrangements, game pricing, and any group-booking options.",
      maxLength: 150,
    },
    {
      question: "No. of Lanes",
      type: QT.NUMBER_STEPPER,
      placeholder: "6 lanes",
    },
    {
      question: "Lane Type",
      type: QT.TEXT,
      placeholder: "Synthetic",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "4",
    },
  ],
  Trampoline: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our trampoline activity area offers an energetic way to jump, move, and have fun. Visitors can enjoy the designated jumping zones while following venue safety instructions and staff guidance. Please check age or height requirements, session duration, grip-sock rules, and supervision arrangements before booking.",
      maxLength: 150,
    },
    {
      question: "No. of Trampolines",
      type: QT.NUMBER_STEPPER,
      placeholder: "10",
    },
    {
      question: "Safety Padding",
      type: QT.TEXT,
      placeholder: "Padded",
    },
    {
      question: "Supervisor",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Age Restriction",
      type: QT.TEXT,
      placeholder: "5+",
    },
    {
      question: "Socks Mandatory",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "15",
    },
  ],
  "Adventure Sports": [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our adventure sports venue offers activity experiences for visitors looking for something active and different. Available experiences, difficulty levels, and age or fitness requirements depend on the activities offered at the venue. Please review the specific activity options, safety briefing, equipment provision, and booking conditions before visiting.",
      maxLength: 150,
    },
    {
      question: "Activity Sub-Type",
      type: QT.TEXT,
      placeholder: "Zipline",
    },
    {
      question: "Safety Equipment",
      type: QT.TEXT,
      placeholder: "Helmet, harness",
    },
    {
      question: "Instructor Present",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Age Restriction",
      type: QT.TEXT,
      placeholder: "10+",
    },
  ],
  "Rock Climbing": [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our rock-climbing facility gives participants a chance to challenge themselves on climbing routes suited to the venue's setup and available skill levels. Staff guidance and safety procedures help visitors understand how to participate. Check whether equipment and instruction are included, along with age requirements and session duration.",
      maxLength: 150,
    },
    {
      question: "Wall Height",
      type: QT.NUMBER,
      unit: "m",
      placeholder: "12 m",
    },
    {
      question: "Harness Provided",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Instructor",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Max Climbers",
      type: QT.NUMBER_STEPPER,
      placeholder: "10",
    },
  ],
  Bouldering: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our bouldering space offers shorter climbing routes over padded landing areas, allowing climbers to practise movement, balance, and problem-solving. It can be enjoyed by newcomers and experienced climbers within the venue's rules. Please check footwear or chalk requirements, safety guidance, age limits, and session access.",
      maxLength: 150,
    },
    {
      question: "Wall Height",
      type: QT.NUMBER,
      unit: "m",
      placeholder: "4 m",
    },
    {
      question: "Crash Mats",
      type: QT.TEXT,
      placeholder: "Thick mats",
    },
    {
      question: "Supervisor",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Chalk Allowed",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Max Climbers",
      type: QT.NUMBER_STEPPER,
      placeholder: "8",
    },
  ],
  Paintball: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our paintball venue offers team-based games built around strategy, movement, and friendly competition. Sessions are conducted under venue rules and safety instructions, with equipment and protective gear subject to the package selected. Check minimum age, included paintballs, protective equipment, group size, and session duration.",
      maxLength: 150,
    },
    {
      question: "Arena Type",
      type: QT.TEXT,
      placeholder: "Outdoor arena",
    },
    {
      question: "Match Format",
      type: QT.TEXT,
      placeholder: "5v5",
    },
    {
      question: "Safety Gear",
      type: QT.TEXT,
      placeholder: "Full gear",
    },
    {
      question: "Referee",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Age Restriction",
      type: QT.TEXT,
      placeholder: "12+",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "10",
    },
  ],
  Boxing: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our boxing facility offers space for fitness training, technique practice, and coached sessions, depending on the timetable. Training may include footwork, bag work, conditioning, and fundamentals. Please ask about beginner classes, coach availability, equipment requirements, and whether sessions involve contact or non-contact training.",
      maxLength: 150,
    },
    {
      question: "Training Area",
      type: QT.NUMBER,
      unit: "sq ft",
      placeholder: "1200 sq ft",
    },
    {
      question: "Ring Available",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Coach Available",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Safety Gear",
      type: QT.TEXT,
      placeholder: "Gloves, pads",
    },
    {
      question: "Max Participants",
      type: QT.NUMBER_STEPPER,
      placeholder: "15",
    },
  ],
  MMA: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our MMA facility provides training opportunities that may combine striking, grappling, and conditioning under suitable coaching and safety rules. Sessions can vary by experience level and training focus. Check the class schedule, coach supervision, required gear, beginner suitability, and whether the session includes sparring.",
      maxLength: 150,
    },
    {
      question: "Training Area",
      type: QT.NUMBER,
      unit: "sq ft",
      placeholder: "1500 sq ft",
    },
    {
      question: "Certified Coach",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Safety Gear",
      type: QT.TEXT,
      placeholder: "Headgear",
    },
    {
      question: "Sparring Allowed",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Max Participants",
      type: QT.NUMBER_STEPPER,
      placeholder: "12",
    },
  ],
  "Martial Arts": [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our martial arts venue offers classes focused on learning techniques, movement, discipline, and controlled practice. The specific style and class format depend on the sessions offered. Please check which martial arts are taught, available levels, instructor arrangements, uniform or equipment requirements, and age groups.",
      maxLength: 150,
    },
    {
      question: "Style",
      type: QT.TEXT,
      placeholder: "Karate",
    },
    {
      question: "Training Area Size",
      type: QT.NUMBER,
      unit: "sq ft",
      placeholder: "1000 sq ft",
    },
    {
      question: "Instructor Available",
      type: QT.TEXT,
      placeholder: "Black belt",
    },
    {
      question: "Safety Gear",
      type: QT.TEXT,
      placeholder: "Protective",
    },
    {
      question: "Batch Size",
      type: QT.NUMBER_STEPPER,
      placeholder: "20",
    },
  ],
  Archery: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our archery venue offers an opportunity to practise aiming and shooting at designated targets in a controlled setting. Participants receive instructions on the venue's range rules and equipment handling. Check equipment inclusion, instructor supervision, minimum age, session duration, and any clothing or safety requirements.",
      maxLength: 150,
    },
    {
      question: "No. of Lanes",
      type: QT.NUMBER_STEPPER,
      placeholder: "10 lanes",
    },
    {
      question: "Bow Type",
      type: QT.TEXT,
      placeholder: "Recurve",
    },
    {
      question: "Distance Range",
      type: QT.TEXT,
      placeholder: "10–30 m",
    },
    {
      question: "Safety Supervision",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Equipment Provided",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Age Restriction",
      type: QT.TEXT,
      placeholder: "8+",
    },
    {
      question: "Max Archers",
      type: QT.NUMBER_STEPPER,
      placeholder: "10",
    },
  ],
  Shooting: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our shooting facility offers a structured target-shooting experience in accordance with venue rules and applicable safety requirements. The available format, equipment, and supervision depend on the facility and session booked. Please confirm eligibility and age requirements, included equipment, instructor supervision, and required identification before booking.",
      maxLength: 150,
    },
    {
      question: "Range Type",
      type: QT.TEXT,
      placeholder: "Indoor range",
    },
    {
      question: "Weapon Type",
      type: QT.TEXT,
      placeholder: "Air pistol",
    },
    {
      question: "License Required",
      type: QT.TEXT,
      placeholder: "No",
    },
    {
      question: "Safety Officer",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Ear Protection",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Max Shooters",
      type: QT.NUMBER_STEPPER,
      placeholder: "6",
    },
  ],
  Swimming: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our swimming facility offers pool access for recreational swimming, practice, or structured lessons where available. Visitors should follow pool rules and any lifeguard or staff instructions. Check pool timings, lane or session access, swimming-level requirements, age rules, and whether lessons or changing facilities are available.",
      maxLength: 150,
    },
    {
      question: "Pool Type",
      type: QT.TEXT,
      placeholder: "Indoor pool",
    },
    {
      question: "Pool Length",
      type: QT.NUMBER,
      unit: "m",
      placeholder: "25 m",
    },
    {
      question: "Max Depth",
      type: QT.NUMBER,
      unit: "ft",
      placeholder: "6 ft",
    },
    {
      question: "Lifeguard",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Changing Rooms",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Coach Available",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Max Swimmers",
      type: QT.NUMBER_STEPPER,
      placeholder: "30",
    },
  ],
  Skating: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our skating venue provides space to practise balance, turns, and skating skills in a designated area. Sessions may suit beginners learning the basics as well as more experienced skaters, depending on venue conditions. Check the skating type, rental equipment, protective gear, instructor availability, and age requirements.",
      maxLength: 150,
    },
    {
      question: "Track Type",
      type: QT.TEXT,
      placeholder: "Concrete track",
    },
    {
      question: "Indoor/Outdoor",
      type: QT.TEXT,
      placeholder: "Outdoor",
    },
    {
      question: "Equipment Rental",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Safety Gear",
      type: QT.TEXT,
      placeholder: "Helmet",
    },
    {
      question: "Instructor",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Age Restriction",
      type: QT.TEXT,
      placeholder: "6+",
    },
    {
      question: "Max Skaters",
      type: QT.NUMBER_STEPPER,
      placeholder: "20",
    },
  ],
  Frisbee: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our venue provides space for frisbee activities, casual throwing practice, and group games, depending on the available area and format. It can be a fun way to build coordination and enjoy time outdoors. Check the playing area, equipment availability, group-size guidance, and any weather-related booking rules.",
      maxLength: 150,
    },
    {
      question: "Ground Type",
      type: QT.TEXT,
      placeholder: "Grass",
    },
    {
      question: "Match Format",
      type: QT.TEXT,
      placeholder: "7v7",
    },
    {
      question: "Equipment Provided",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "14",
    },
    {
      question: "Referee",
      type: QT.TEXT,
      placeholder: "Yes",
    },
  ],
  Equestrian: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our equestrian facility offers horse-related experiences such as riding lessons or guided rides, depending on the services available. Activities are conducted according to the venue's safety procedures and instructor guidance. Please confirm rider experience requirements, age or weight limits, protective equipment, session duration, and what is included.",
      maxLength: 150,
    },
    {
      question: "No. of Horses",
      type: QT.NUMBER_STEPPER,
      placeholder: "8 horses",
    },
    {
      question: "Trainer Present",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Safety Gear",
      type: QT.TEXT,
      placeholder: "Helmet",
    },
    {
      question: "Experience Level",
      type: QT.TEXT,
      placeholder: "Beginner",
    },
  ],
  Padbol: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our padbol court offers a space to play this football-based game on a court enclosed by walls, where permitted by the venue's setup. Players can enjoy rallies, teamwork, and friendly competition. Please check the court format, footwear requirements, ball availability, group size, and booking duration.",
      maxLength: 150,
    },
    {
      question: "No. of Courts",
      type: QT.NUMBER_STEPPER,
      placeholder: "1 court",
    },
    {
      question: "Court Type",
      type: QT.TEXT,
      placeholder: "Standard",
    },
    {
      question: "Indoor/Outdoor",
      type: QT.TEXT,
      placeholder: "Outdoor",
    },
    {
      question: "Surface Type",
      type: QT.TEXT,
      placeholder: "Artificial turf",
    },
    {
      question: "Lighting",
      type: QT.TEXT,
      placeholder: "LED",
    },
    {
      question: "Equipment Provided",
      type: QT.TEXT,
      placeholder: "Yes",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "4",
    },
  ],
  "Pool Table": [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our pool-table area offers a place to enjoy casual games, practise shots, and compete with friends. Visitors can book table time for a relaxed outing or focused practice. Check the table type, session duration, equipment availability, and whether bookings are charged by time or game.",
      maxLength: 150,
    },
    {
      question: "No. of Tables",
      type: QT.NUMBER_STEPPER,
      placeholder: "3 tables",
    },
    {
      question: "Table Type",
      type: QT.TEXT,
      placeholder: "Pool",
    },
    {
      question: "Table Size",
      type: QT.TEXT,
      placeholder: "7 ft",
    },
    {
      question: "Max Players",
      type: QT.NUMBER_STEPPER,
      placeholder: "4",
    },
  ],
  Others: [
    {
      question: "Activity Description",
      type: QT.TEXTAREA,
      required: true,
      placeholder: "Our venue offers an activity experience designed for people who want to stay active, learn a skill, or enjoy time with others. Describe what participants will do, what facilities or equipment are available, who can join, and what makes the experience special. Please include any important requirements or booking instructions.",
      maxLength: 150,
    },
    {
      question: "Activity Name",
      type: QT.TEXT,
      placeholder: "Parkour",
    },
    {
      question: "Indoor/Outdoor",
      type: QT.TEXT,
      placeholder: "Indoor",
    },
    {
      question: "Capacity",
      type: QT.NUMBER_STEPPER,
      placeholder: "15",
    },
    {
      question: "Equipment Provided",
      type: QT.TEXT,
      placeholder: "Basic",
    },
    {
      question: "Safety Measures",
      type: QT.TEXT,
      placeholder: "Mats",
    },
    {
      question: "Session Duration",
      type: QT.NUMBER,
      unit: "mins",
      placeholder: "60 mins",
    },
  ],
  Teqball: [
    { question: "Activity Description", type: QT.TEXTAREA, required: true, maxLength: 150 },
    { question: "Total Tables", type: QT.NUMBER_STEPPER, placeholder: "1 table" },
    { question: "Table Quality", type: QT.TEXT, placeholder: "Tournament grade" },
  ],
};

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
