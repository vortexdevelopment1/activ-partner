Backend is Running & Connected to Neon PostgreSQL
Database: Neon connected successfully via SSL in ~3.6 seconds. TypeORM auto-synced all tables.

Project Structure

src/
├── common/           Guards, decorators, filters, interceptors, enums
├── config/           database.config.ts (SSL always on for Neon)
├── database/seeds/   Admin user seeder
└── modules/
    ├── auth/         Login, register (user/partner), change password
    ├── users/        Full CRUD (admin only)
    ├── partners/     Full CRUD + own profile management
    ├── categories/   Admin CRUD + public read
    ├── questions/    Admin CRUD, per-category & global, reorder
    ├── venues/       Create, approval flow, services, images, answers
    ├── bookings/     Book slots, conflict detection, status management
    └── payments/     Razorpay order creation + signature verification
Available Commands

npm run start:dev     # Development with hot reload
npm run start:prod    # Production (uses dist/)
npm run build         # Compile TypeScript
npm run seed          # Create admin user in DB
API Base & Docs
Base URL: http://localhost:3000/api/v1
Swagger UI: http://localhost:3000/api/docs
Default Admin Credentials (after npm run seed)
Email: admin@activproduct.com
Password: Admin@123
Roles & Access
Role	Access
admin	All CRUD, approve/reject venues, manage users/partners
partner	Create/manage venues, view their bookings
user	Browse venues, book, pay
Venue Approval Flow
partner creates venue → pending → admin reviews → approved or rejected (with reason required)

Read C:\Users\Admin-PC\AppData\Local\Temp\claude\d--ActivProduct-Backend\tasks\bcc80b3.output
npm install completed successfully — 779 packages installed. The warnings are just deprecation notices from transitive dev dependencies (eslint, glob, etc.) and don't affect the app.

Everything is ready. Here's what to run next:


# 1. Start in dev mode (hot reload)
npm run start:dev

# 2. Seed the admin user (run once)
npm run seed

# 3. Access Swagger docs
http://localhost:3000/api/docs
Login with admin credentials:

Email: admin@activproduct.com
Password: Admin@123
Read C:\Users\Admin-PC\AppData\Local\Temp\claude\d--ActivProduct-Backend\tasks\b7d6bab.output
The log confirms everything is working perfectly. Here's what the output shows:

✅ All good — the EADDRINUSE error is NOT a real problem.

Line 2 shows the Swagger JSON was returned successfully — meaning the first server instance was already running and serving on port 3000. When the script tried to start a second instance on the same port, it got the EADDRINUSE conflict. That's expected.

Confirmed working:

Line 10: TypeOrmCoreModule initialized (+3634ms) — Neon DB connected via SSL
Lines 18–25: All 8 modules loaded (Users, Partners, Categories, Questions, Venues, Bookings, Payments, Auth)
Lines 27–99: All 37 routes mapped across all controllers
Line 100: Nest application successfully started ✅
The backend is fully operational. Just run it normally:


# Kill any leftover process first, then start dev mode
npm run start:dev
Then seed the admin once:


npm run seed