import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { dbStore } from '../db/store.js';

export async function recommendationRoutes(app: FastifyInstance): Promise<void> {
  app.get('/', async (request: FastifyRequest, reply: FastifyReply) => {
    let userId = 'usr_anni_demo_001';
    try {
      await request.jwtVerify();
      userId = (request.user as { sub: string }).sub;
    } catch {
      // Guest fallback uses seeded demo affinity
    }

    const allTracks = dbStore.getAllTracks();
    const history = dbStore.getPlayHistory(userId, 20);
    const favorites = dbStore.getFavorites(userId);

    // Compute genre affinity from history + favorites
    const genreScores = new Map<string, number>();
    for (const h of history) {
      if (h.track) {
        genreScores.set(h.track.genre, (genreScores.get(h.track.genre) ?? 0) + 2);
      }
    }
    for (const fav of favorites) {
      genreScores.set(fav.genre, (genreScores.get(fav.genre) ?? 0) + 3);
    }

    const rankedForYou = [...allTracks].sort((a, b) => {
      const scoreA = genreScores.get(a.genre) ?? 0;
      const scoreB = genreScores.get(b.genre) ?? 0;
      return scoreB - scoreA;
    });

    const recentlyPlayed = history
      .map((h) => h.track)
      .filter((t): t is NonNullable<typeof t> => Boolean(t));

    const uniqueRecent = Array.from(new Map(recentlyPlayed.map((t) => [t.id, t])).values());

    const mixes = [
      {
        id: 'mix_made_for_you_1',
        title: 'Made For You: Nocturnal Mix',
        subtitle: 'Aether & Nova, Kairo Vance, Lyra Vex',
        gradientColors: ['#8B5CF6', '#EC4899', '#F59E0B'],
        coverUrl:
          'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&auto=format&fit=crop&q=80',
        tracks: rankedForYou.slice(0, 6),
      },
      {
        id: 'mix_daily_lossless',
        title: 'Daily Lossless Reference',
        subtitle: '24-Bit FLAC Studio Masters & Chamber Works',
        gradientColors: ['#06B6D4', '#3B82F6', '#8B5CF6'],
        coverUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&auto=format&fit=crop&q=80',
        tracks: allTracks.filter((t) => t.qualityBadge === 'FLAC'),
      },
      {
        id: 'mix_late_night_lofi',
        title: 'Late Night Velvet Focus',
        subtitle: 'Warm Rhodes, Lo-Fi & Indie Acoustic',
        gradientColors: ['#F59E0B', '#EC4899', '#8B5CF6'],
        coverUrl:
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=80',
        tracks: allTracks.filter((t) => ['Lo-Fi', 'Jazz', 'Indie Rock'].includes(t.genre)),
      },
      {
        id: 'mix_bollywood_romance',
        title: 'Bollywood Romance & Acoustic',
        subtitle: 'Arijit Singh, Pritam, Mithoon, Shreya Ghoshal',
        gradientColors: ['#EC4899', '#F43F5E', '#FB923C'],
        coverUrl:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&auto=format&fit=crop&q=80',
        tracks: allTracks.filter((t) => ['Bollywood', 'Hindi'].includes(t.genre)),
      },
      {
        id: 'mix_punjabi_heat',
        title: 'Punjabi Heat & Heavy 808s',
        subtitle: 'Sidhu Moose Wala, Diljit Dosanjh, Intense',
        gradientColors: ['#EF4444', '#F59E0B', '#8B5CF6'],
        coverUrl:
          'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=800&auto=format&fit=crop&q=80',
        tracks: allTracks.filter((t) => t.genre === 'Punjabi'),
      },
      {
        id: 'mix_south_cinema',
        title: 'South Indian Cinema Top Hits',
        subtitle: 'Anirudh Ravichander, Keeravani, Jonita Gandhi',
        gradientColors: ['#06B6D4', '#3B82F6', '#10B981'],
        coverUrl:
          'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800&auto=format&fit=crop&q=80',
        tracks: allTracks.filter((t) => ['Tamil', 'Telugu', 'Malayalam'].includes(t.genre)),
      },
    ];

    const topArtists = [
      {
        id: 'artist_arijit_singh',
        name: 'Arijit Singh',
        genre: 'Bollywood / Soul',
        avatarUrl:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400&auto=format&fit=crop&q=80',
        monthlyListeners: '38.4M',
      },
      {
        id: 'artist_sidhu_moosewala',
        name: 'Sidhu Moose Wala',
        genre: 'Punjabi',
        avatarUrl:
          'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&auto=format&fit=crop&q=80',
        monthlyListeners: '18.2M',
      },
      {
        id: 'artist_anirudh',
        name: 'Anirudh Ravichander',
        genre: 'Tamil / Indian',
        avatarUrl:
          'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400&auto=format&fit=crop&q=80',
        monthlyListeners: '14.9M',
      },
      {
        id: 'artist_diljit_dosanjh',
        name: 'Diljit Dosanjh',
        genre: 'Punjabi / Pop',
        avatarUrl:
          'https://images.unsplash.com/photo-1557672172-298e090bd0f1?w=400&auto=format&fit=crop&q=80',
        monthlyListeners: '22.1M',
      },
      {
        id: 'artist_aether_nova',
        name: 'Aether & Nova',
        genre: 'Electronic',
        avatarUrl:
          'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400&auto=format&fit=crop&q=80',
        monthlyListeners: '142K',
      },
      {
        id: 'artist_kairo_vance',
        name: 'Kairo Vance',
        genre: 'Synthwave',
        avatarUrl:
          'https://images.unsplash.com/photo-1557672172-298e090bd0f1?w=400&auto=format&fit=crop&q=80',
        monthlyListeners: '98K',
      },
      {
        id: 'artist_nordic_chamber',
        name: 'Nordic Chamber Collective',
        genre: 'Ambient / Classical',
        avatarUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=400&auto=format&fit=crop&q=80',
        monthlyListeners: '76K',
      },
      {
        id: 'artist_sora_velvet',
        name: 'Sora & The Velvet Keys',
        genre: 'Lo-Fi',
        avatarUrl:
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400&auto=format&fit=crop&q=80',
        monthlyListeners: '210K',
      },
      {
        id: 'artist_julian_mercer',
        name: 'Julian Mercer Quartet',
        genre: 'Jazz',
        avatarUrl:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400&auto=format&fit=crop&q=80',
        monthlyListeners: '64K',
      },
    ];

    return reply.send({
      heroTrack: allTracks[0],
      madeForYouMixes: mixes,
      recentlyPlayed: uniqueRecent.length > 0 ? uniqueRecent : allTracks.slice(0, 4),
      trending: allTracks.slice(0, 8),
      topArtists,
    });
  });
}
