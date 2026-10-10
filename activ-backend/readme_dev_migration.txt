✅ Migration Setup Complete
What was created/updated:

File	Purpose
src/data-source.ts	Standalone TypeORM DataSource for CLI (SSL enabled for Neon)
src/database/migrations/1771168802993-InitialSchema.ts	Baseline migration — all 10 tables + 14 indexes
The migration is now recorded in the migrations table on Neon DB — INSERT INTO "migrations" ... InitialSchema1771168802993 confirmed.

Migration Commands

# Run all pending migrations
npm run migration:run

# Revert last migration
npm run migration:revert

# Show migration status (run vs pending)
npm run migration:show

# Generate a new migration after changing an entity
npm run migration:generate src/database/migrations/YourMigrationName

# Create a blank migration
npm run migration:create src/database/migrations/YourMigrationName
Workflow for future schema changes
Edit your entity (e.g. add a column to User)
Run npm run migration:generate src/database/migrations/AddColumnToUser
TypeORM compares entity vs DB and auto-generates the diff SQL
Review the generated file, then run npm run migration:run