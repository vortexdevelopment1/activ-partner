import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export interface SearchItem {
  id: string;
  label: string;
  description: string;
  path: string;
}

export interface SearchGroup {
  key: string;
  title: string;
  items: SearchItem[];
}

@Injectable()
export class AdminSearchService {
  constructor(private readonly prisma: PrismaService) {}

  async search(query: string): Promise<SearchGroup[]> {
    const term = query.trim();
    if (term.length < 2) return [];
    const match = { contains: term, mode: 'insensitive' as const };
    const listPath = (path: string, value: string) =>
      `${path}?search=${encodeURIComponent(value)}`;
    const [venues, partners, users, categories, questions, faqs, commissions,
      bankAccounts, gstRequests, venueRequests, callbacks] = await Promise.all([
      this.prisma.venues.findMany({
        where: { OR: [
          { name: match }, { city_code: match },
          { partner_venue_profiles: { is: { city: match } } },
        ] },
        select: { id: true, name: true, city_code: true, partner_venue_profiles: { select: { city: true, state: true } } },
        orderBy: { submitted_at: 'desc' }, take: 5,
      }),
      this.prisma.partners.findMany({
        where: { OR: [
          { legal_name: match },
          { partner_business_profiles: { is: { OR: [
            { business_name: match }, { owner_name: match }, { email: match },
            { phone_e164: { contains: term } }, { city: match },
          ] } } },
        ] },
        select: { id: true, legal_name: true, partner_business_profiles: { select: { business_name: true, city: true } } },
        orderBy: { created_at: 'desc' }, take: 5,
      }),
      this.prisma.users.findMany({
        where: { OR: [{ name: match }, { email: match }, { phone_e164: { contains: term } }] },
        select: { id: true, name: true, email: true, phone_e164: true },
        orderBy: { created_at: 'desc' }, take: 5,
      }),
      this.prisma.partner_service_categories.findMany({
        where: { OR: [{ name: match }, { description: match }] },
        select: { id: true, name: true, description: true },
        orderBy: { name: 'asc' }, take: 5,
      }),
      this.prisma.partner_service_questions.findMany({
        where: { question: match },
        select: { id: true, question: true, partner_service_categories: { select: { id: true, name: true } } },
        orderBy: { sort_order: 'asc' }, take: 5,
      }),
      this.prisma.faqs.findMany({
        where: { OR: [{ question: match }, { answer: match }] },
        select: { id: true, question: true },
        orderBy: { sort_order: 'asc' }, take: 5,
      }),
      this.prisma.partner_city_commissions.findMany({
        where: { partner_id: null, OR: [{ city_code: match }, { state_code: match }] },
        select: { id: true, city_code: true, state_code: true, commission_bps: true },
        orderBy: { city_code: 'asc' }, take: 5,
      }),
      this.prisma.partner_bank_accounts.findMany({
        where: { OR: [
          { account_holder_name: match }, { bank_name: match },
          { ifsc_code: match }, { account_number: { contains: term } },
        ] },
        select: { id: true, account_holder_name: true, bank_name: true },
        orderBy: { created_at: 'desc' }, take: 5,
      }),
      this.prisma.partner_gst_verification_requests.findMany({
        where: { OR: [{ gst_number: match }, { legal_name: match }] },
        select: { id: true, gst_number: true, legal_name: true },
        orderBy: { created_at: 'desc' }, take: 5,
      }),
      this.prisma.partner_venue_update_requests.findMany({
        where: { venues: { name: match } },
        select: { id: true, venues: { select: { name: true } }, status: true },
        orderBy: { created_at: 'desc' }, take: 5,
      }),
      this.prisma.partner_callback_requests.findMany({
        where: { OR: [{ subject: match }, { notes: match }] },
        select: { id: true, subject: true, status: true },
        orderBy: { created_at: 'desc' }, take: 5,
      }),
    ]);

    return [
      { key: 'venues', title: 'Venues', items: venues.map((venue) => ({
        id: venue.id, label: venue.name,
        description: [venue.partner_venue_profiles?.city || venue.city_code, venue.partner_venue_profiles?.state].filter(Boolean).join(', '),
        path: `/venues/${venue.id}`,
      })) },
      { key: 'partners', title: 'Partners', items: partners.map((partner) => ({
        id: partner.id, label: partner.partner_business_profiles?.business_name || partner.legal_name,
        description: partner.partner_business_profiles?.city || 'Partner',
        path: listPath('/partners', partner.partner_business_profiles?.business_name || partner.legal_name),
      })) },
      { key: 'users', title: 'Users', items: users.map((user) => ({
        id: user.id, label: user.name || user.email || user.phone_e164,
        description: user.email || user.phone_e164,
        path: listPath('/users', user.email || user.phone_e164),
      })) },
      { key: 'categories', title: 'Categories', items: categories.map((category) => ({
        id: category.id, label: category.name, description: category.description || 'Category',
        path: listPath('/categories', category.name),
      })) },
      { key: 'questions', title: 'Questions', items: questions.map((question) => ({
        id: question.id, label: question.question,
        description: question.partner_service_categories?.name || 'Global question',
        path: `${listPath('/questions', question.question)}&categoryId=${question.partner_service_categories?.id || 'global'}`,
      })) },
      { key: 'faqs', title: 'FAQs', items: faqs.map((faq) => ({
        id: faq.id, label: faq.question, description: 'FAQ',
        path: listPath('/faqs', faq.question),
      })) },
      { key: 'commissions', title: 'Commissions', items: commissions.map((commission) => ({
        id: commission.id, label: commission.city_code,
        description: `${commission.state_code || 'All states'} - ${commission.commission_bps / 100}%`,
        path: listPath('/commissions', commission.city_code),
      })) },
      { key: 'bank-accounts', title: 'Bank Accounts', items: bankAccounts.map((account) => ({
        id: account.id, label: account.account_holder_name, description: account.bank_name,
        path: `/bank-accounts/${account.id}`,
      })) },
      { key: 'gst-verification', title: 'GST Verification', items: gstRequests.map((request) => ({
        id: request.id, label: request.legal_name || request.gst_number,
        description: request.gst_number, path: `/gst-verification/${request.id}`,
      })) },
      { key: 'venue-requests', title: 'Venue Requests', items: venueRequests.map((request) => ({
        id: request.id, label: request.venues.name,
        description: `${request.status.toLowerCase()} update request`,
        path: `/venue-requests/${request.id}`,
      })) },
      { key: 'support', title: 'Support', items: callbacks.map((request) => ({
        id: request.id, label: request.subject,
        description: `${request.status.toLowerCase()} callback`,
        path: `/support/callback/${request.id}`,
      })) },
    ].filter((group) => group.items.length > 0);
  }
}
