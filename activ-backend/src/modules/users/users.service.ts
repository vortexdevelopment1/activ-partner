import { randomUUID } from 'crypto';
import * as bcrypt from 'bcryptjs';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { UserStatus } from '../../generated/prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { UserRole } from '../../common/enums/user-role.enum';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  private mapUser(user: any) {
    const names = (user.name || '').trim().split(/\s+/);
    const isPartner = Array.isArray(user.partner_users) && user.partner_users.length > 0;
    return {
      id: user.id,
      firstName: names[0] || null,
      lastName: names.slice(1).join(' ') || null,
      email: user.email,
      phone: user.phone_e164,
      role: user.is_admin ? UserRole.ADMIN : isPartner ? UserRole.PARTNER : UserRole.USER,
      isActive: user.status === UserStatus.ACTIVE,
      isEmailVerified: Boolean(user.email),
      profileImage: user.profile_photo,
      createdAt: user.created_at,
      updatedAt: user.updated_at,
    };
  }

  async create(dto: CreateUserDto) {
    if (await this.prisma.users.findFirst({ where: { email: dto.email } })) {
      throw new ConflictException('User with this email already exists');
    }
    if (!dto.phone) {
      throw new BadRequestException('Phone number is required');
    }
    const user = await this.prisma.users.create({
      data: {
        id: randomUUID(),
        name: `${dto.firstName} ${dto.lastName}`.trim(),
        email: dto.email,
        phone_e164: dto.phone,
        password_hash: await bcrypt.hash(dto.password, 10),
        is_admin: dto.role === UserRole.ADMIN,
        updated_at: new Date(),
      },
      include: { partner_users: true },
    });
    return this.mapUser(user);
  }

  async findAll(pagination: PaginationDto, role?: UserRole) {
    const where: any = {};
    if (role === UserRole.ADMIN) where.is_admin = true;
    if (role === UserRole.PARTNER) where.partner_users = { some: {} };
    if (role === UserRole.USER) {
      where.is_admin = false;
      where.partner_users = { none: {} };
    }
    if (pagination.search) {
      where.OR = [
        { name: { contains: pagination.search, mode: 'insensitive' } },
        { email: { contains: pagination.search, mode: 'insensitive' } },
        { phone_e164: { contains: pagination.search } },
      ];
    }
    const [users, total] = await Promise.all([
      this.prisma.users.findMany({
        where,
        include: { partner_users: true },
        skip: pagination.skip,
        take: pagination.limit,
        orderBy: { created_at: 'desc' },
      }),
      this.prisma.users.count({ where }),
    ]);
    return [users.map((user) => this.mapUser(user)), total] as const;
  }

  async findOne(id: string) {
    const user = await this.prisma.users.findUnique({
      where: { id },
      include: { partner_users: true },
    });
    if (!user) throw new NotFoundException(`User with id ${id} not found`);
    return this.mapUser(user);
  }

  async findByEmail(email: string) {
    const user = await this.prisma.users.findFirst({
      where: { email: { equals: email, mode: 'insensitive' } },
      include: { partner_users: true },
    });
    return user ? this.mapUser(user) : null;
  }

  async update(id: string, dto: UpdateUserDto) {
    const current = await this.prisma.users.findUnique({ where: { id } });
    if (!current) throw new NotFoundException(`User with id ${id} not found`);
    const currentNames = (current.name || '').trim().split(/\s+/);
    const firstName = dto.firstName ?? currentNames[0] ?? '';
    const lastName = dto.lastName ?? currentNames.slice(1).join(' ');
    const user = await this.prisma.users.update({
      where: { id },
      data: {
        name: `${firstName} ${lastName}`.trim(),
        email: dto.email,
        phone_e164: dto.phone,
        is_admin: dto.role === undefined ? undefined : dto.role === UserRole.ADMIN,
        status: dto.isActive === undefined
          ? undefined
          : dto.isActive ? UserStatus.ACTIVE : UserStatus.SUSPENDED,
        updated_at: new Date(),
      },
      include: { partner_users: true },
    });
    return this.mapUser(user);
  }

  async remove(id: string): Promise<void> {
    await this.findOne(id);
    await this.prisma.users.delete({ where: { id } });
  }

  async toggleStatus(id: string) {
    const current = await this.prisma.users.findUnique({ where: { id } });
    if (!current) throw new NotFoundException(`User with id ${id} not found`);
    return this.update(id, { isActive: current.status !== UserStatus.ACTIVE });
  }

  async updatePassword(id: string, newPassword: string): Promise<void> {
    await this.prisma.users.update({
      where: { id },
      data: { password_hash: await bcrypt.hash(newPassword, 10), updated_at: new Date() },
    });
  }

  async updateProfileImage(id: string, imageUrl: string) {
    const user = await this.prisma.users.update({
      where: { id },
      data: { profile_photo: imageUrl, updated_at: new Date() },
      include: { partner_users: true },
    });
    return this.mapUser(user);
  }
}
