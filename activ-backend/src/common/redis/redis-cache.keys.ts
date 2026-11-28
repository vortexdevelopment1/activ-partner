import { createHash } from 'crypto';

export const CACHE_TTL_SECONDS = {
  MASTER_AMENITIES: 12 * 60 * 60,
  MASTER_CATEGORIES: 12 * 60 * 60,
  MASTER_QUESTIONS: 12 * 60 * 60,
  MASTER_FAQ: 60 * 60,
  MASTER_LEGAL: 60 * 60,
  COMMISSION_CONFIG: 5 * 60,
  VENUE_DETAILS: 5 * 60,
  VENUE_LIST: 3 * 60,
  VENUE_ACTIVITIES: 5 * 60,
  PARTNER_PROFILE: 5 * 60,
  PARTNER_TEAM: 90,
  PARTNER_BOOKING_STATS: 45,
  PARTNER_PAYOUT_HISTORY: 3 * 60,
  PARTNER_NOTIFICATION_COUNT: 20,
  ADMIN_DASHBOARD: 45,
  ADMIN_LISTS: 60,
  ADMIN_NOTIFICATION_COUNT: 20,
} as const;

/** Adds +/-10% randomized jitter to prevent synchronized cache avalanches. */
export function withTtlJitter(ttlSeconds: number): number {
  const safe = Math.max(1, Math.floor(ttlSeconds));
  if (safe < 10) return safe;
  const spread = Math.max(1, Math.floor(safe * 0.1));
  const delta = Math.floor(Math.random() * (spread * 2 + 1)) - spread;
  return Math.max(5, safe + delta);
}

/** Produces a deterministic 16-char hash from query parameters, omitting empty values. */
export function canonicalQueryHash(params: Record<string, unknown>): string {
  const normalized: Record<string, unknown> = {};
  for (const key of Object.keys(params).sort()) {
    const value = params[key];
    if (value === undefined || value === null || value === '') continue;
    normalized[key] = typeof value === 'string' ? value.trim() : value;
  }
  return createHash('sha256')
    .update(JSON.stringify(normalized))
    .digest('hex')
    .slice(0, 16);
}

export class CacheKeys {
  constructor(
    private readonly prefix: string,
    private readonly env: string,
  ) {}

  private key(segment: string): string {
    return `${this.prefix}:${this.env}:partner:v1:${segment}`;
  }

  tag(name: string): string {
    return this.key(`tag:${name}`);
  }

  masterAmenities(): string {
    return this.key('master:amenities:active');
  }

  masterCategoriesActive(): string {
    return this.key('master:categories:active');
  }

  masterCategoriesList(query: Record<string, unknown>): string {
    return this.key(`master:categories:list:${canonicalQueryHash(query)}`);
  }

  masterQuestions(categoryId?: string): string {
    return this.key(`master:questions:${categoryId || 'all'}`);
  }

  masterFaqActive(): string {
    return this.key('master:faq:active');
  }

  masterFaqList(query: Record<string, unknown>): string {
    return this.key(`master:faq:list:${canonicalQueryHash(query)}`);
  }

  masterLegal(type: string): string {
    return this.key(`master:legal:${type}`);
  }

  commissionDefault(): string {
    return this.key('commission:default');
  }

  commissionCities(query: Record<string, unknown>): string {
    return this.key(`commission:cities:${canonicalQueryHash(query)}`);
  }

  commissionAllIndianCities(query: Record<string, unknown>): string {
    return this.key(`commission:indian-cities:${canonicalQueryHash(query)}`);
  }

  partnerProfile(partnerId: string): string {
    return this.key(`partner:${partnerId}:profile`);
  }

  partnerTeam(partnerId: string): string {
    return this.key(`partner:${partnerId}:team`);
  }

  partnerVenues(partnerId: string): string {
    return this.key(`partner:${partnerId}:venues`);
  }

  partnerApprovedVenues(partnerId: string): string {
    return this.key(`partner:${partnerId}:venues:approved`);
  }

  venueDetails(venueId: string): string {
    return this.key(`venue:${venueId}:details`);
  }

  venueActivities(venueId: string): string {
    return this.key(`venue:${venueId}:activities`);
  }

  venueFullActivities(venueId: string): string {
    return this.key(`venue:${venueId}:activities:full`);
  }

  partnerBookingStats(partnerId: string, venueId?: string): string {
    return this.key(`partner:${partnerId}:booking-stats:${venueId || 'all'}`);
  }

  partnerPayoutHistory(partnerId: string, query: Record<string, unknown>): string {
    return this.key(`partner:${partnerId}:payout-history:${canonicalQueryHash(query)}`);
  }

  partnerNotificationsUnread(userId: string): string {
    return this.key(`partner-user:${userId}:notifications:unread`);
  }

  adminNotificationsUnread(): string {
    return this.key('admin:notifications:unread');
  }

  adminVenueStats(): string {
    return this.key('admin:venues:stats');
  }

  adminVenues(query: Record<string, unknown>): string {
    return this.key(`admin:venues:list:${canonicalQueryHash(query)}`);
  }

  adminVenueDetail(venueId: string): string {
    return this.key(`admin:venue:${venueId}:detail`);
  }

  adminPartners(query: Record<string, unknown>): string {
    return this.key(`admin:partners:list:${canonicalQueryHash(query)}`);
  }

  adminTransactions(query: Record<string, unknown>): string {
    return this.key(`admin:transactions:${canonicalQueryHash(query)}`);
  }
}
