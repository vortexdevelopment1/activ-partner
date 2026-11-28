import { Module } from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { PaymentsController } from './payments.controller';
import { AdminTransactionsController } from './admin-transactions.controller';
import { AdminTransactionsService } from './admin-transactions.service';

@Module({
  imports: [],
  controllers: [PaymentsController, AdminTransactionsController],
  providers: [PaymentsService, AdminTransactionsService],
  exports: [PaymentsService],
})
export class PaymentsModule {}
