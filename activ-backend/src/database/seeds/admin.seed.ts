import { DataSource } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import { User } from '../../modules/users/entities/user.entity';
import { UserRole } from '../../common/enums/user-role.enum';

export async function seedAdmin(dataSource: DataSource) {
  const userRepository = dataSource.getRepository(User);

  const adminEmail = process.env.ADMIN_EMAIL || 'admin@activproduct.com';
  const adminPassword = process.env.ADMIN_PASSWORD || 'Admin@123';

  const existingAdmin = await userRepository.findOne({
    where: { email: adminEmail, role: UserRole.ADMIN },
  });

  if (!existingAdmin) {
    const hashedPassword = await bcrypt.hash(adminPassword, 10);

    const admin = userRepository.create({
      firstName: 'Super',
      lastName: 'Admin',
      email: adminEmail,
      password: hashedPassword,
      role: UserRole.ADMIN,
      isActive: true,
      isEmailVerified: true,
    });

    await userRepository.save(admin);
    console.log(`✅ Admin user created: ${adminEmail}`);
  } else {
    console.log(`ℹ️  Admin user already exists: ${adminEmail}`);
  }
}
