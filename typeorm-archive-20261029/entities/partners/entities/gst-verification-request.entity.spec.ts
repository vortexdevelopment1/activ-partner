import { DataSource } from 'typeorm';
import { GstVerificationRequest, GstVerificationStatus } from './gst-verification-request.entity';

describe('GST verification schema compatibility', () => {
  let source: DataSource;

  beforeAll(async () => {
    source = new DataSource({ type: 'postgres', entities: [GstVerificationRequest] });
    await (source as any).buildMetadatas();
  });

  it('queries the normalized schema and transforms status filter parameters', () => {
    const [sql, parameters] = source.getRepository(GstVerificationRequest)
      .createQueryBuilder('gst')
      .where({ partnerId: 'partner-id', status: GstVerificationStatus.PENDING })
      .andWhere('(gst.gstNumber ILIKE :search OR gst.gstName ILIKE :search)', { search: '%test%' })
      .orderBy('gst.createdAt', 'DESC')
      .getQueryAndParameters();

    expect(sql).toContain('FROM "partner_gst_verification_requests"');
    for (const column of ['partner_id', 'gst_number', 'legal_name', 'document_url', 'rejection_reason', 'created_at', 'updated_at']) {
      expect(sql).toContain(`"gst"."${column}"`);
    }
    expect(parameters).toEqual(['partner-id', 'PENDING', '%test%']);
  });

  it('preserves lowercase API statuses when reading and writing the shared enum', () => {
    const column = source.getMetadata(GstVerificationRequest).findColumnWithPropertyName('status')!;
    for (const status of Object.values(GstVerificationStatus)) {
      expect(source.driver.preparePersistentValue(status, column)).toBe(status.toUpperCase());
      expect(source.driver.prepareHydratedValue(status.toUpperCase(), column)).toBe(status);
    }
  });
});
