export interface CatalogTrack {
  id: string;
  source: 'jamendo' | 'internet_archive' | 'youtube' | 'local' | 'jiosaavn';
  externalId: string;
  title: string;
  artist: string;
  album: string;
  genre: string;
  durationSeconds: number;
  artworkUrl: string;
  streamUrl: string | null;
  downloadUrl: string | null;
  youtubeVideoId?: string;
  qualityBadge: 'FLAC' | '320kbps' | '256kbps' | 'YT-HD';
  license: string;
  releaseYear: number;
  waveform: number[];
  dominantColor: string;
  syncedLrc?: string;
}

const generateWaveform = (seed: number): number[] => {
  const points: number[] = [];
  for (let i = 0; i < 64; i++) {
    const v =
      0.22 +
      0.45 * Math.abs(Math.sin((i + seed) * 0.27)) +
      0.3 * Math.abs(Math.cos((i * 1.7 + seed) * 0.19));
    points.push(Number(Math.min(0.98, Math.max(0.12, v)).toFixed(2)));
  }
  return points;
};

export const INITIAL_LEGAL_CATALOG: CatalogTrack[] = [
  {
    id: 'jamendo_1884921',
    source: 'jamendo',
    externalId: '1884921',
    title: 'Midnight Velvet Horizon',
    artist: 'Aether & Nova',
    album: 'Nocturnal Odyssey',
    genre: 'Electronic',
    durationSeconds: 224,
    artworkUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&auto=format&fit=crop&q=80',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    qualityBadge: 'FLAC',
    license: 'CC BY-SA 4.0 (Jamendo Free Music)',
    releaseYear: 2025,
    waveform: generateWaveform(1),
    dominantColor: '#8B5CF6',
    syncedLrc: `[00:00.00] ♪ Instrumental Intro — Midnight Velvet Horizon ♪
[00:12.40] Neon reflections across the obsidian glass
[00:18.90] Every heartbeat echoes where the shadows pass
[00:25.50] Drifting through the frequencies of purple light
[00:32.10] We are weightless in the velvet of the night
[00:40.00] Hold the signal close, let the bassline breathe
[00:48.20] All the static fades underneath our feet
[00:56.80] In your music, in your world, we come alive
[01:05.40] Chasing horizons past the edge of time`,
  },
  {
    id: 'jamendo_1902341',
    source: 'jamendo',
    externalId: '1902341',
    title: 'Solaris Pulse',
    artist: 'Kairo Vance',
    album: 'Prism Architecture',
    genre: 'Synthwave',
    durationSeconds: 198,
    artworkUrl: 'https://images.unsplash.com/photo-1557672172-298e090bd0f1?w=800&auto=format&fit=crop&q=80',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    qualityBadge: 'FLAC',
    license: 'CC BY 4.0 (Jamendo)',
    releaseYear: 2025,
    waveform: generateWaveform(2),
    dominantColor: '#EC4899',
    syncedLrc: `[00:00.00] ♪ Synth Arpeggio Intro ♪
[00:10.50] Amber sun rising over chrome boulevards
[00:17.20] Analog memories written in the stars
[00:24.80] Feel the Solaris pulse running through the wire
[00:32.00] Magenta skylines burning higher and higher
[00:41.30] Turn the dial up until the speakers glow
[00:50.10] Nowhere left to hide, everywhere to go`,
  },
  {
    id: 'ia_cc_flac_001',
    source: 'internet_archive',
    externalId: 'cc_aurora_borealis_flac',
    title: 'Aurora Borealis (Uncompressed Studio Master)',
    artist: 'Nordic Chamber Collective',
    album: 'Glacial Harmonics',
    genre: 'Ambient',
    durationSeconds: 256,
    artworkUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&auto=format&fit=crop&q=80',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    qualityBadge: 'FLAC',
    license: 'CC0 1.0 Public Domain (Internet Archive)',
    releaseYear: 2024,
    waveform: generateWaveform(3),
    dominantColor: '#06B6D4',
    syncedLrc: `[00:00.00] ♪ Ambient Cello & Glass Harp Intro ♪
[00:15.00] Ribbons of emerald across the arctic sky
[00:24.50] Silence speaks louder when the northern winds sigh
[00:36.00] Crystalline echoes in a cathedral of ice
[00:48.00] Breathing in stillness, pure and precise`,
  },
  {
    id: 'jamendo_1948102',
    source: 'jamendo',
    externalId: '1948102',
    title: 'Amber Afterglow',
    artist: 'Sora & The Velvet Keys',
    album: 'Late Night Lo-Fi Sessions',
    genre: 'Lo-Fi',
    durationSeconds: 185,
    artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=80',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    qualityBadge: '320kbps',
    license: 'CC BY-NC-SA 4.0 (Jamendo)',
    releaseYear: 2025,
    waveform: generateWaveform(4),
    dominantColor: '#F59E0B',
    syncedLrc: `[00:00.00] ♪ Warm Rhodes & Vinyl Crackle ♪
[00:09.80] Raindrops tapping on the studio pane
[00:16.40] Coffee steam curling like a slow refrain
[00:23.00] Golden amber afterglow on seventy-eight rpm
[00:31.50] Rewind the tape and play it all again`,
  },
  {
    id: 'ia_cc_jazz_002',
    source: 'internet_archive',
    externalId: 'ia_blue_note_midnight',
    title: 'Espresso at Midnight',
    artist: 'Julian Mercer Quartet',
    album: 'Live at Studio B',
    genre: 'Jazz',
    durationSeconds: 242,
    artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&auto=format&fit=crop&q=80',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
    downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
    qualityBadge: 'FLAC',
    license: 'CC BY 4.0 (Internet Archive Live Music Archive)',
    releaseYear: 2024,
    waveform: generateWaveform(5),
    dominantColor: '#D97706',
    syncedLrc: `[00:00.00] ♪ Upright Bass & Brush Drums Intro ♪
[00:14.20] Brass notes floating through the velvet room
[00:22.00] Midnight espresso and a saxophone bloom
[00:31.80] Walking the changes on a silver string
[00:40.50] Let the quartet swing till the morning brings`,
  },
  {
    id: 'jamendo_1992011',
    source: 'jamendo',
    externalId: '1992011',
    title: 'Cybernetic Bloom',
    artist: 'Lyra Vex',
    album: 'Hyperion',
    genre: 'Electronic',
    durationSeconds: 210,
    artworkUrl: 'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800&auto=format&fit=crop&q=80',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
    downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
    qualityBadge: 'FLAC',
    license: 'CC BY 4.0 (Jamendo)',
    releaseYear: 2025,
    waveform: generateWaveform(6),
    dominantColor: '#A855F7',
  },
  {
    id: 'ia_cc_classical_003',
    source: 'internet_archive',
    externalId: 'ia_moonlight_reimagined',
    title: 'Clair de Lune (24-Bit Remaster)',
    artist: 'Elena Rostova',
    album: 'Impressionist Piano Works',
    genre: 'Classical',
    durationSeconds: 301,
    artworkUrl: 'https://images.unsplash.com/photo-1520523839897-bd0b52f945a0?w=800&auto=format&fit=crop&q=80',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
    downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
    qualityBadge: 'FLAC',
    license: 'Public Domain Mark 1.0 (Internet Archive)',
    releaseYear: 2023,
    waveform: generateWaveform(7),
    dominantColor: '#3B82F6',
  },
  {
    id: 'jamendo_2014882',
    source: 'jamendo',
    externalId: '2014882',
    title: 'Obsidian Drift',
    artist: 'SubZero Theory',
    album: 'Bassline Manifesto',
    genre: 'Hip-Hop',
    durationSeconds: 176,
    artworkUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=800&auto=format&fit=crop&q=80',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
    downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
    qualityBadge: '320kbps',
    license: 'CC BY-SA 4.0 (Jamendo)',
    releaseYear: 2025,
    waveform: generateWaveform(8),
    dominantColor: '#EF4444',
  },
  {
    id: 'ia_cc_indie_004',
    source: 'internet_archive',
    externalId: 'ia_pacific_coastline',
    title: 'Pacific Coastline Drive',
    artist: 'The Sunlit Pines',
    album: 'Westward Wanderer',
    genre: 'Indie Rock',
    durationSeconds: 219,
    artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&auto=format&fit=crop&q=80',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
    downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
    qualityBadge: '320kbps',
    license: 'CC BY-NC 4.0 (Free Music Archive / IA)',
    releaseYear: 2024,
    waveform: generateWaveform(9),
    dominantColor: '#10B981',
  },
  {
    id: 'jamendo_2059104',
    source: 'jamendo',
    externalId: '2059104',
    title: 'Starlight Sanctuary',
    artist: 'Aether & Nova',
    album: 'Nocturnal Odyssey',
    genre: 'Electronic',
    durationSeconds: 234,
    artworkUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800&auto=format&fit=crop&q=80',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',
    downloadUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',
    qualityBadge: 'FLAC',
    license: 'CC BY-SA 4.0 (Jamendo)',
    releaseYear: 2025,
    waveform: generateWaveform(10),
    dominantColor: '#6366F1',
  },
  {
    id: 'youtube_jfKfPfyJRdk',
    source: 'youtube',
    externalId: 'jfKfPfyJRdk',
    youtubeVideoId: 'jfKfPfyJRdk',
    title: 'lofi hip hop radio — beats to relax/study to (Official IFrame Stream)',
    artist: 'Lofi Girl',
    album: 'YouTube Official Stream',
    genre: 'Lo-Fi',
    durationSeconds: 3600,
    artworkUrl: 'https://i.ytimg.com/vi/jfKfPfyJRdk/maxresdefault.jpg',
    streamUrl: null, // Strictly uses official YouTube IFrame Player
    downloadUrl: null, // Strictly disabled for YouTube per ToS
    qualityBadge: 'YT-HD',
    license: 'YouTube Standard License (Official IFrame Playback Only)',
    releaseYear: 2025,
    waveform: generateWaveform(11),
    dominantColor: '#EC4899',
  },
  {
    id: 'youtube_4xDzrJKXOOY',
    source: 'youtube',
    externalId: '4xDzrJKXOOY',
    youtubeVideoId: '4xDzrJKXOOY',
    title: 'synthwave radio — chillsynth / retro beats (Official IFrame Stream)',
    artist: 'Lofi Girl Synthwave',
    album: 'YouTube Official Stream',
    genre: 'Synthwave',
    durationSeconds: 3600,
    artworkUrl: 'https://i.ytimg.com/vi/4xDzrJKXOOY/maxresdefault.jpg',
    streamUrl: null,
    downloadUrl: null,
    qualityBadge: 'YT-HD',
    license: 'YouTube Standard License (Official IFrame Playback Only)',
    releaseYear: 2025,
    waveform: generateWaveform(12),
    dominantColor: '#8B5CF6',
  },
  {
    id: 'jiosaavn_kesariya_01',
    source: 'jiosaavn',
    externalId: 'kesariya_01',
    title: 'Kesariya (Acoustic Strings Master)',
    artist: 'Arijit Singh & Pritam',
    album: 'Brahmāstra — Curated Indian Sessions',
    genre: 'Bollywood',
    durationSeconds: 268,
    artworkUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&auto=format&fit=crop&q=80',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    downloadUrl: null,
    qualityBadge: '320kbps',
    license: 'JioSaavn Official Streaming Partner Catalog',
    releaseYear: 2025,
    waveform: generateWaveform(13),
    dominantColor: '#F59E0B',
    syncedLrc: `[00:00.00] ♪ Sitar & Acoustic Strings Intro ♪
[00:15.20] Mujhko itna bataye koyi
[00:23.00] Kaise tujhse dil na lagaye koyi
[00:32.40] Kesariya tera ishq hai piya
[00:41.20] Rang jaaun jo main haath lagaun`,
  },
  {
    id: 'jiosaavn_tum_hi_ho_02',
    source: 'jiosaavn',
    externalId: 'tum_hi_ho_02',
    title: 'Tum Hi Ho (Soulful Nocturne)',
    artist: 'Arijit Singh & Mithoon',
    album: 'Aashiqui 2 (Anniversary Sessions)',
    genre: 'Hindi',
    durationSeconds: 262,
    artworkUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=80',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    downloadUrl: null,
    qualityBadge: '320kbps',
    license: 'JioSaavn Official Streaming Partner Catalog',
    releaseYear: 2024,
    waveform: generateWaveform(14),
    dominantColor: '#8B5CF6',
    syncedLrc: `[00:00.00] ♪ Piano Solo Nocturne ♪
[00:18.00] Hum tere bin ab reh nahi sakte
[00:27.50] Tere bina kya wajood mera
[00:36.00] Kyunki tum hi ho, ab tum hi ho
[00:44.20] Zindagi ab tum hi ho`,
  },
  {
    id: 'jiosaavn_punjabi_03',
    source: 'jiosaavn',
    externalId: 'punjabi_295',
    title: '295 (Urban Bassline Redux)',
    artist: 'Sidhu Moose Wala',
    album: 'Moosetape Redux',
    genre: 'Punjabi',
    durationSeconds: 270,
    artworkUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=800&auto=format&fit=crop&q=80',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    downloadUrl: null,
    qualityBadge: '320kbps',
    license: 'JioSaavn Official Streaming Partner Catalog',
    releaseYear: 2024,
    waveform: generateWaveform(15),
    dominantColor: '#EF4444',
  },
  {
    id: 'jiosaavn_punjabi_04',
    source: 'jiosaavn',
    externalId: 'lover_punjabi',
    title: 'Lover (Neon Punjabi Beats)',
    artist: 'Diljit Dosanjh & Intense',
    album: 'MoonChild Era',
    genre: 'Punjabi',
    durationSeconds: 198,
    artworkUrl: 'https://images.unsplash.com/photo-1557672172-298e090bd0f1?w=800&auto=format&fit=crop&q=80',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    downloadUrl: null,
    qualityBadge: '320kbps',
    license: 'JioSaavn Official Streaming Partner Catalog',
    releaseYear: 2025,
    waveform: generateWaveform(16),
    dominantColor: '#EC4899',
  },
  {
    id: 'jiosaavn_tamil_05',
    source: 'jiosaavn',
    externalId: 'arabic_kuthu_tamil',
    title: 'Arabic Kuthu — Halamithi Habibo',
    artist: 'Anirudh Ravichander & Jonita Gandhi',
    album: 'Beast (Cinematic Master)',
    genre: 'Tamil',
    durationSeconds: 280,
    artworkUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&auto=format&fit=crop&q=80',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
    downloadUrl: null,
    qualityBadge: '320kbps',
    license: 'JioSaavn Official Streaming Partner Catalog',
    releaseYear: 2025,
    waveform: generateWaveform(17),
    dominantColor: '#06B6D4',
  },
  {
    id: 'jiosaavn_telugu_06',
    source: 'jiosaavn',
    externalId: 'naatu_naatu_telugu',
    title: 'Naatu Naatu (High Energy Orchestral)',
    artist: 'M. M. Keeravani, Rahul Sipligunj, Kaala Bhairava',
    album: 'RRR',
    genre: 'Telugu',
    durationSeconds: 215,
    artworkUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800&auto=format&fit=crop&q=80',
    streamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
    downloadUrl: null,
    qualityBadge: '320kbps',
    license: 'JioSaavn Official Streaming Partner Catalog',
    releaseYear: 2024,
    waveform: generateWaveform(18),
    dominantColor: '#F97316',
  },
];
