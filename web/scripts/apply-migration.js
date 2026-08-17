const { PrismaClient } = require('@prisma/client');
const fs = require('fs');
const path = require('path');

const sqlPath = path.join(__dirname, '..', 'prisma', 'migrations', '20260817010000_category_tag_many_to_many', 'migration.sql');
const sql = fs.readFileSync(sqlPath, 'utf8');

(async () => {
  const db = new PrismaClient();
  try {
    const statements = sql.split(/;\s*$/m).filter(s => s.trim().length > 0);
    for (const stmt of statements) {
      try {
        await db.$executeRawUnsafe(stmt + ';');
        console.log('OK:', stmt.replace(/\s+/g, ' ').slice(0, 90));
      } catch (e) {
        console.log('SKIP (already exists?):', stmt.replace(/\s+/g, ' ').slice(0, 90), '-', e.message.slice(0, 80));
      }
    }
    console.log('DONE');
  } finally {
    await db.$disconnect();
  }
})();