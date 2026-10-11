import { dbStore } from '../src/db/store.js';

async function runSeed(): Promise<void> {
  console.log('🌱 Seeding Anni Music ("Your music. Your world.") database...');
  const seeded = dbStore.createSeedState();
  dbStore.persist();

  console.log('✅ Seed completed successfully:');
  console.log(`   • Users:         ${seeded.users.length} (Demo login: demo@annimusic.app / AnniMusic2026!)`);
  console.log(`   • Legal Tracks:  ${seeded.tracks.length} (Jamendo FLAC, Internet Archive CC, YouTube Official IFrame)`);
  console.log(`   • Playlists:     ${seeded.playlists.length}`);
  console.log(`   • Favorites:     ${seeded.favorites.length}`);
  console.log(`   • Play History:  ${seeded.playHistory.length}`);
  console.log(`   • Synced Lyrics: ${seeded.lyricsCache.length}`);
}

void runSeed();
