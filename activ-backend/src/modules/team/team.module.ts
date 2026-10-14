import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TeamMember } from './entities/team-member.entity';
import { TeamService } from './team.service';
import { TeamController } from './team.controller';

@Module({
  imports: [TypeOrmModule.forFeature([TeamMember])],
  controllers: [TeamController],
  providers: [TeamService],
  exports: [TeamService],
})
export class TeamModule {}
