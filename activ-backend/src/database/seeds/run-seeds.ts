import 'reflect-metadata';
import { DataSource } from 'typeorm';
import * as dotenv from 'dotenv';
import { seedAdmin } from './admin.seed';
import { seedCategories } from './categories.seed';
import { seedQuestions } from './questions.seed';

dotenv.config();

const isNeon = (process.env.DB_HOST || '').includes('neon.tech');

const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  username: process.env.DB_USERNAME || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  database: process.env.DB_DATABASE || 'activ_product_db',
  entities: [__dirname + '/../../**/*.entity{.ts,.js}'],
  synchronize: false,
  ssl: isNeon ? { rejectUnauthorized: false } : false,
});

async function runSeeds() {
  try {
    await AppDataSource.initialize();
    console.log('📦 Database connected. Running seeds...\n');

    await seedAdmin(AppDataSource);

    console.log('\n🌱 Seeding categories...');
    await seedCategories(AppDataSource);

    console.log('\n🌱 Seeding questions...');
    await seedQuestions(AppDataSource);

    console.log('\n✅ All seeds completed successfully!');
    await AppDataSource.destroy();
    process.exit(0);
  } catch (error) {
    console.error('❌ Error running seeds:', error);
    process.exit(1);
  }
}

runSeeds();
