import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like, FindManyOptions } from 'typeorm';
import { User } from './entities/user.entity';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { UserRole } from '../../common/enums/user-role.enum';
import { PaginationDto } from '../../common/dto/pagination.dto';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async create(createUserDto: CreateUserDto): Promise<User> {
    const existing = await this.userRepository.findOne({
      where: { email: createUserDto.email },
    });

    if (existing) {
      throw new ConflictException('User with this email already exists');
    }

    const user = this.userRepository.create(createUserDto);
    return this.userRepository.save(user);
  }

  async findAll(pagination: PaginationDto, role?: UserRole) {
    const where: any = {};

    if (role) where.role = role;

    if (pagination.search) {
      return this.userRepository.findAndCount({
        where: [
          { ...where, firstName: Like(`%${pagination.search}%`) },
          { ...where, lastName: Like(`%${pagination.search}%`) },
          { ...where, email: Like(`%${pagination.search}%`) },
        ],
        skip: pagination.skip,
        take: pagination.limit,
        order: { createdAt: 'DESC' },
      });
    }

    return this.userRepository.findAndCount({
      where,
      skip: pagination.skip,
      take: pagination.limit,
      order: { createdAt: 'DESC' },
    });
  }

  async findOne(id: string): Promise<User> {
    const user = await this.userRepository.findOne({ where: { id } });
    if (!user) {
      throw new NotFoundException(`User with id ${id} not found`);
    }
    return user;
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.userRepository.findOne({ where: { email } });
  }

  async update(id: string, updateUserDto: UpdateUserDto): Promise<User> {
    const user = await this.findOne(id);

    if (updateUserDto.email && updateUserDto.email !== user.email) {
      const existing = await this.userRepository.findOne({
        where: { email: updateUserDto.email },
      });
      if (existing) {
        throw new ConflictException('Email already in use');
      }
    }

    Object.assign(user, updateUserDto);
    return this.userRepository.save(user);
  }

  async remove(id: string): Promise<void> {
    const user = await this.findOne(id);
    await this.userRepository.remove(user);
  }

  async toggleStatus(id: string): Promise<User> {
    const user = await this.findOne(id);
    user.isActive = !user.isActive;
    return this.userRepository.save(user);
  }

  async updatePassword(id: string, newPassword: string): Promise<void> {
    const user = await this.findOne(id);
    user.password = newPassword;
    await this.userRepository.save(user);
  }

  async updateProfileImage(id: string, imageUrl: string): Promise<User> {
    const user = await this.findOne(id);
    user.profileImage = imageUrl;
    return this.userRepository.save(user);
  }
}
