export type EmailProvider = 'legacy' | 'gmail' | 'smtp';

export type EmailMethod = 'template' | 'agreement' | 'smtpAgreement' | 'suspension'
  | 'changes' | 'approval' | 'invitation' | 'reset' | 'callback' | 'support' | 'rejection';

/** Encrypted at rest, including temporary passwords, reset codes and PDF bytes. */
export interface EmailJob {
  provider: EmailProvider;
  method: EmailMethod;
  recipient: string;
  params: any;
  eventKey?: string;
  expiresAt?: string;
}

export interface DeliveryResult {
  sent: boolean;
  queued?: boolean;
  messageId?: string;
}

export const serializeJob = (job: EmailJob) => JSON.stringify(job);
export const deserializeJob = (value: string): EmailJob => JSON.parse(value, (_key, item) =>
  item?.type === 'Buffer' && Array.isArray(item.data) ? Buffer.from(item.data) : item);
