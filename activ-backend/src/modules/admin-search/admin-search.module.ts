import { Module } from '@nestjs/common';
import { AdminSearchController } from './admin-search.controller';
import { AdminSearchService } from './admin-search.service';

@Module({ controllers: [AdminSearchController], providers: [AdminSearchService] })
export class AdminSearchModule {}
