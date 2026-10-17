import { BadRequestException, ConflictException } from "@nestjs/common";
import { CommissionService } from "./commission.service";

describe("location commissions", () => {
  const now = new Date();
  const rule = {
    id: "rule-1",
    partner_id: null,
    city_code: "mumbai",
    state_code: "maharashtra",
    commission_bps: 500,
    effective_from: now,
    effective_to: null,
    created_at: now,
    updated_at: now,
  };
  let table: any;
  let service: CommissionService;

  beforeEach(() => {
    table = {
      findFirst: jest.fn().mockResolvedValue(null),
      findUnique: jest.fn().mockResolvedValue(rule),
      create: jest
        .fn()
        .mockImplementation(({ data }) =>
          Promise.resolve({ ...rule, ...data }),
        ),
      update: jest
        .fn()
        .mockImplementation(({ data }) =>
          Promise.resolve({ ...rule, ...data }),
        ),
      findMany: jest.fn().mockResolvedValue([]),
    };
    service = new CommissionService({ partner_city_commissions: table } as any);
  });

  it("returns the admin city-and-state rate as 5%, normalized by location", async () => {
    table.findFirst.mockResolvedValue(rule);
    expect(
      await service.getCommissionByCity(" MUMBAI ", " Maharashtra "),
    ).toMatchObject({ commissionPercentage: 5, isDefault: false });
    expect(table.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          partner_id: null,
          city_code: { equals: "mumbai", mode: "insensitive" },
          state_code: { equals: "maharashtra", mode: "insensitive" },
          effective_from: { lte: expect.any(Date) },
          OR: [
            { effective_to: null },
            { effective_to: { gte: expect.any(Date) } },
          ],
        }),
      }),
    );
    expect(table.findFirst).toHaveBeenCalledTimes(1);
  });

  it("preserves city-only rules before falling back to a state rule", async () => {
    table.findFirst
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({ ...rule, state_code: null });
    expect(
      (await service.getCommissionByCity("Mumbai", "Maharashtra"))
        .commissionPercentage,
    ).toBe(5);
    expect(table.findFirst).toHaveBeenCalledTimes(2);
    expect(table.findFirst.mock.calls[1][0].where.state_code).toBeNull();
  });

  it("uses a state-wide rule for a city without its own rate", async () => {
    table.findFirst
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({ ...rule, city_code: "", commission_bps: 750 });
    expect(
      (await service.getCommissionByCity("Pune", "Maharashtra"))
        .commissionPercentage,
    ).toBe(7.5);
    expect(table.findFirst.mock.calls[2][0].where.city_code.equals).toBe("");
  });

  it("uses the backend default only when no active location rule matches", async () => {
    expect(
      await service.getCommissionByCity("Pune", "Maharashtra"),
    ).toMatchObject({ commissionPercentage: 5, isDefault: true });
  });

  it("uses the editable nationwide rule when one has been saved", async () => {
    table.findFirst
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({ ...rule, city_code: "", state_code: null, commission_bps: 650 });

    expect(
      await service.getCommissionByCity("Pune", "Maharashtra"),
    ).toMatchObject({ commissionPercentage: 6.5, isDefault: true });
  });

  it("persists the nationwide default so admins can change it later", async () => {
    await expect(service.updateDefaultCommission(5.5)).resolves.toEqual({
      commissionPercentage: 5.5,
      isPersisted: true,
    });
    expect(table.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        city_code: "",
        state_code: null,
        commission_bps: 550,
      }),
    });
  });

  it("saves state-wide rules with basis-point precision", async () => {
    expect(
      await service.create({
        state: " Maharashtra ",
        commissionPercentage: 5.25,
      }),
    ).toMatchObject({
      city: "",
      state: "maharashtra",
      commissionPercentage: 5.25,
    });
    expect(table.create.mock.calls[0][0].data.commission_bps).toBe(525);
  });

  it("rejects empty locations and duplicate rules", async () => {
    await expect(
      service.create({ city: " ", state: "", commissionPercentage: 5 }),
    ).rejects.toBeInstanceOf(BadRequestException);
    table.findFirst.mockResolvedValue(rule);
    await expect(
      service.create({
        city: "Mumbai",
        state: "Maharashtra",
        commissionPercentage: 5,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it("updates rates and lets the admin clear the state for a city-only rule", async () => {
    expect(
      await service.update(rule.id, { state: "", commissionPercentage: 6 }),
    ).toMatchObject({ city: "mumbai", state: null, commissionPercentage: 6 });
  });

  it("lists Indian cities with the effective nationwide rate", async () => {
    const [cities, total] = await service.findAllIndianCities({
      page: 1,
      limit: 5,
      search: "Mumbai",
      skip: 0,
    } as any);

    expect(total).toBeGreaterThan(0);
    expect(cities[0]).toMatchObject({
      city: expect.stringMatching(/Mumbai/i),
      state: "Maharashtra",
      commissionPercentage: 5,
      source: "default",
      overrideId: null,
    });
  });
});
