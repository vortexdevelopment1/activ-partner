import { ACTIVITY_FIELDS } from "./activity-detail-fields.seed";
import { CATEGORIES } from "./categories.seed";

describe("activity detail field catalogue", () => {
  it("matches the approved activity sheet exactly", () => {
    expect(Object.keys(ACTIVITY_FIELDS).sort()).toEqual(
      CATEGORIES.map(([name]) => name).sort(),
    );
    expect(Object.keys(ACTIVITY_FIELDS)).toHaveLength(39);
  });

  it("uses the supplied Gym, Adventure Sports, Badminton, Basketball and Others field definitions", () => {
    expect(ACTIVITY_FIELDS.Gym.map((field) => field.question)).toEqual([
      "Activity Description",
      "Total Floor Area",
      "Max Capacity",
      "Equipment Categories",
      "Trainer Availability",
      "Ventilation Type",
      "Locker & Shower",
      "Peak Hours",
    ]);
    expect(
      ACTIVITY_FIELDS["Adventure Sports"].map((field) => field.question),
    ).toEqual([
      "Activity Description",
      "Activity Sub-Type",
      "Safety Equipment",
      "Instructor Present",
      "Age Restriction",
    ]);
    expect(ACTIVITY_FIELDS.Badminton.map((field) => field.question)).toEqual([
      "Activity Description",
      "No. of Courts",
      "Indoor/Outdoor",
      "Flooring Type",
      "Ceiling Height",
      "Lighting Quality",
      "Equipment Provided",
      "Max Players",
    ]);
    expect(ACTIVITY_FIELDS.Basketball.map((field) => field.question)).toEqual([
      "Activity Description",
      "No. of Courts",
      "Full/Half Court",
      "Indoor/Outdoor",
      "Floor Type",
      "Lighting",
      "Ball Provided",
      "Max Players",
    ]);
    expect(ACTIVITY_FIELDS.Others.map((field) => field.question)).toEqual([
      "Activity Description",
      "Activity Name",
      "Indoor/Outdoor",
      "Capacity",
      "Equipment Provided",
      "Safety Measures",
      "Session Duration",
    ]);
    expect(ACTIVITY_FIELDS["Adventure Sports"][0]).toMatchObject({
      required: true,
      type: "TEXTAREA",
      maxLength: 150,
    });
  });
});
