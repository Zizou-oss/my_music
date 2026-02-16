// file: screens/home_screen.dart
import 'dart:async';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/db_helper.dart';
import '../models/song.dart';
import '../player/audio_handler.dart';
import 'NowPlayingScreen.dart';

enum LibrarySection { songs, favorites }

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _favoritesKey = 'favorite_song_ids';
  static const String _youtubeUrl = 'https://youtube.com/@2blockofficiel?si=rzLQehwNQCcmS7qe';
  static const String _tiktokUrl = 'https://www.tiktok.com/@2blockofficiel';
  static const String _facebookUrl = 'https://bit.ly/4mfVSKK';

  final AudioHandler _handler = AudioHandler();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Song> songs = [];
  List<Song> filteredSongs = [];

  bool _isSearching = false;
  bool _isLoading = true;
  String _sortMode = 'default';

  LibrarySection _activeSection = LibrarySection.songs;
  Set<int> _favoriteIds = <int>{};

  @override
  void initState() {
    super.initState();
    _handler.addListener(_onAudioHandlerChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadUserData();
    await _loadSongs();
  }

  void _onAudioHandlerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _handler.removeListener(_onAudioHandlerChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteRaw = prefs.getStringList(_favoritesKey) ?? <String>[];

    final loadedFavorites = favoriteRaw
        .map(int.tryParse)
        .whereType<int>()
        .toSet();

    if (!mounted) return;
    setState(() {
      _favoriteIds = loadedFavorites;
    });
  }

  Future<void> _persistFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoritesKey,
      _favoriteIds.map((id) => id.toString()).toList(),
    );
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    try {
      final data = await DBHelper.getSongs();
      if (!mounted) return;
      setState(() {
        songs = data;
        _isLoading = false;
        _applyFiltersAndSort(_searchController.text);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        songs = [];
        filteredSongs = [];
      });
      _showSnackBar(context, 'Erreur chargement bibliotheque');
    }
  }

  void _playSong(Song song) {
    _handler.playSong(song);
  }

  Future<void> _openNowPlaying(Song song) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NowPlayingScreen(song: song)),
    );
    await _loadUserData();
    if (!mounted) return;
    setState(() {
      _applyFiltersAndSort(_searchController.text);
    });
  }

  void _setSection(LibrarySection section) {
    setState(() {
      _activeSection = section;
      _applyFiltersAndSort(_searchController.text);
    });
  }

  void _goToNextSection() {
    if (_activeSection == LibrarySection.songs) {
      _setSection(LibrarySection.favorites);
    }
  }

  void _goToPreviousSection() {
    if (_activeSection == LibrarySection.favorites) {
      _setSection(LibrarySection.songs);
    }
  }

  void _onHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 120) return;

    if (velocity < 0) {
      _goToNextSection();
    } else {
      _goToPreviousSection();
    }
  }

  void _filterSongs(String query) {
    setState(() {
      _applyFiltersAndSort(query);
    });
  }

  void _applyFiltersAndSort(String query) {
    final searchLower = query.toLowerCase().trim();

    List<Song> source;
    if (_activeSection == LibrarySection.favorites) {
      source = songs.where((song) => _favoriteIds.contains(song.id)).toList();
    } else {
      source = List<Song>.from(songs);
    }

    List<Song> result;
    if (searchLower.isEmpty) {
      result = source;
    } else {
      result = source.where((song) {
        final titleLower = song.title.toLowerCase();
        final artistLower = song.artist.toLowerCase();
        return titleLower.contains(searchLower) || artistLower.contains(searchLower);
      }).toList();
    }

    if (_sortMode == 'az') {
      result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_sortMode == 'za') {
      result.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
    } else if (_sortMode == 'recent') {
      result.sort((a, b) => b.id.compareTo(a.id));
    }

    filteredSongs = result;
  }

  void _setSortMode(String mode) {
    setState(() {
      _sortMode = mode;
      _applyFiltersAndSort(_searchController.text);
    });
  }

  String _sortLabel() {
    switch (_sortMode) {
      case 'az':
        return 'A-Z';
      case 'za':
        return 'Z-A';
      case 'recent':
        return 'Plus recent';
      default:
        return 'Par defaut';
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (_isSearching) {
        _searchFocusNode.requestFocus();
      } else {
        _searchController.clear();
        _searchFocusNode.unfocus();
        _applyFiltersAndSort('');
      }
    });
  }

  Future<void> _toggleFavorite(int songId) async {
    setState(() {
      if (_favoriteIds.contains(songId)) {
        _favoriteIds.remove(songId);
      } else {
        _favoriteIds.add(songId);
      }
      _applyFiltersAndSort(_searchController.text);
    });
    await _persistFavorites();
  }

  String _sectionCountLabel() {
    return '${filteredSongs.length} son(s)';
  }

  Widget _buildSectionPill({
    required LibrarySection section,
    required String label,
  }) {
    final selected = _activeSection == section;

    return InkWell(
      onTap: () => _setSection(section),
      child: SizedBox(
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.black : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 2.5,
              width: selected ? 44 : 0,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = _handler.currentSong;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _filterSongs,
                style: const TextStyle(fontSize: 18, color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Rechercher un son...',
                  hintStyle: TextStyle(fontSize: 18, color: Colors.grey[400]),
                  border: InputBorder.none,
                ),
              )
            : const Text(
                '2Block Music',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.black,
                ),
              ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close, size: 26, color: Colors.black),
              onPressed: _toggleSearch,
            )
          else
            IconButton(
              icon: const Icon(Icons.search, size: 26, color: Colors.black),
              onPressed: _toggleSearch,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, size: 26, color: Colors.black),
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            onSelected: (value) {
              _handleMenuSelection(value, context);
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        const Text(
                          '2Block Music',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'V 1.2.0',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                _buildMenuItem(context, 'about', Icons.info_outline, 'A propos', Colors.black),
                _buildMenuItem(
                  context,
                  'facebook',
                  Icons.facebook,
                  'Facebook',
                  const Color(0xFF1877F2),
                ),
                _buildMenuItem(
                  context,
                  'tiktok',
                  FontAwesomeIcons.tiktok,
                  'TikTok',
                  Colors.black,
                ),
                _buildMenuItem(
                  context,
                  'youtube',
                  Icons.video_library,
                  'YouTube',
                  Colors.red,
                ),
                const PopupMenuDivider(),
                _buildMenuItem(
                  context,
                  'donate',
                  Icons.volunteer_activism,
                  'Soutenir le projet',
                  Colors.black,
                ),
              ];
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  Expanded(
                    child: _buildSectionPill(
                      section: LibrarySection.songs,
                      label: 'Nos songs',
                    ),
                  ),
                  Expanded(
                    child: _buildSectionPill(
                      section: LibrarySection.favorites,
                      label: 'Favoris',
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _sectionCountLabel(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: _setSortMode,
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'default', child: Text('Par defaut')),
                      PopupMenuItem(value: 'az', child: Text('Titre A-Z')),
                      PopupMenuItem(value: 'za', child: Text('Titre Z-A')),
                      PopupMenuItem(value: 'recent', child: Text('Plus recent')),
                    ],
                    child: Row(
                      children: [
                        const Icon(Icons.sort, size: 18, color: Colors.black87),
                        const SizedBox(width: 6),
                        Text(
                          _sortLabel(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: _onHorizontalSwipe,
              child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Chargement de la bibliotheque...',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : _buildSongsListView(),
              ),
            ),
          ),
          if (currentSong != null)
            StreamBuilder<Duration>(
              stream: _handler.player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? _handler.player.position;
                final duration = _handler.player.duration ?? Duration.zero;
                final progress = duration.inMilliseconds == 0
                    ? 0.0
                    : position.inMilliseconds / duration.inMilliseconds;
                return _buildMiniPlayer(context, currentSong, progress);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSongsListView() {
    if (filteredSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSearching ? Icons.search_off : Icons.music_off,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 20),
            Text(
              _isSearching ? 'Aucun resultat trouve' : 'Aucun son disponible',
              style: TextStyle(fontSize: 18, color: Colors.grey[400]),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _loadSongs,
              icon: const Icon(Icons.refresh),
              label: const Text('Recharger'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSongs,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filteredSongs.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          thickness: 0.5,
          indent: 70,
          color: Colors.grey,
        ),
        itemBuilder: (context, index) {
          final song = filteredSongs[index];
          final isCurrentSong = _handler.currentSong?.id == song.id;
          final isFavorite = _favoriteIds.contains(song.id);

          return Material(
            color: isCurrentSong ? Colors.red.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _playSong(song),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isCurrentSong ? Colors.black : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/${song.cover}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.music_note, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            song.artist,
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Favori',
                      onPressed: () => _toggleFavorite(song.id),
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    BuildContext context,
    String value,
    IconData icon,
    String label,
    Color iconColor,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 15),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuSelection(String value, BuildContext context) {
    switch (value) {
      case 'about':
        _showAboutDialog(context);
        break;
      case 'facebook':
        _openExternalLink(_facebookUrl);
        break;
      case 'tiktok':
        _openExternalLink(_tiktokUrl);
        break;
      case 'youtube':
        _openExternalLink(_youtubeUrl);
        break;
      case 'donate':
        _showDonationDialog(context);
        break;
    }
  }

  Future<void> _openExternalLink(String url) async {
    Uri uri = Uri.parse(url.trim());
    if (!uri.hasScheme) {
      uri = Uri.parse('https://${url.trim()}');
    }
    bool opened = false;

    try {
      if (await canLaunchUrl(uri)) {
        opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!opened) {
        opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
      if (!opened) {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      opened = false;
    }

    if (!opened && mounted) {
      _showSnackBar(context, 'Impossible d ouvrir le lien');
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '2Block Music',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  'Version 1.2.0',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                const Text(
                  '2Block Music est une application developpee par THIOMBIANO TECH.\n\n'
                  'Profitez de votre musique preferee ou que vous soyez.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Fermer',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDonationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.1),
                  ),
                  child: const Icon(Icons.volunteer_activism, size: 40, color: Colors.black),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Soutenir le projet',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                Text(
                  'Votre soutien nous aide a maintenir et ameliorer cette application.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Pour faire un don :',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.phone, color: Colors.black),
                          SizedBox(width: 10),
                          Text(
                            '+226 55 04 12 79',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniPlayer(BuildContext context, Song song, double progress) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              minHeight: 3,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _openNowPlaying(song),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/images/${song.cover}', fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openNowPlaying(song),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist,
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous, size: 28, color: Colors.red),
                      onPressed: () {
                        _handler.previousSong();
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        _handler.player.playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 36,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        if (_handler.player.playing) {
                          _handler.player.pause();
                        } else {
                          _handler.playSong(song);
                        }
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 28, color: Colors.red),
                      onPressed: () {
                        _handler.nextSong();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}



