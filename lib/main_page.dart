import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login/login_page.dart';
import 'scan_page.dart';
import 'new_farmer_page.dart';
import 'hamburger/app_drawer.dart';
import 'hamburger/settings_page.dart'; // for AppSettings

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  // Hamburger drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Drag handle / expandable sheet ────────────────────────────
  // 0.0 = normal (header visible), 1.0 = expanded (card covers the screen)
  late final AnimationController _sheetController;
  final GlobalKey _headerKey = GlobalKey();
  double _headerHeight = 300; // updated with the real height at drag start

  @override
  void initState() {
    super.initState();
    _sheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _measureHeader() {
    final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.size.height > 0) {
      _headerHeight = box.size.height;
    }
  }

  void _onHandleDragStart(DragStartDetails details) {
    _sheetController.stop();
    _measureHeader();
  }

  void _onHandleDragUpdate(DragUpdateDetails details) {
    // Dragging up (negative dy) expands, dragging down collapses.
    final delta = -details.delta.dy / _headerHeight;
    _sheetController.value = (_sheetController.value + delta).clamp(0.0, 1.0);
  }

  void _onHandleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    double target;
    if (velocity < -300) {
      target = 1.0;
    } else if (velocity > 300) {
      target = 0.0;
    } else {
      target = _sheetController.value > 0.5 ? 1.0 : 0.0;
    }
    _sheetController.animateTo(target, curve: Curves.easeOut);
  }

  void _toggleSheet() {
    _measureHeader();
    final target = _sheetController.value > 0.5 ? 0.0 : 1.0;
    _sheetController.animateTo(target, curve: Curves.easeInOut);
  }

  // ── Logout ────────────────────────────────────────────────────
  // Signs out, then replaces the WHOLE navigation stack with a fresh
  // LoginPage. (Do NOT push CaneVisionApp here - it is a MaterialApp, and
  // nesting one inside another causes the black screen.)
  Future<void> _logout() async {
    // Respect the "Confirm before logging out" setting
    final needsConfirm = await AppSettings.confirmLogout();
    if (!mounted) return;

    bool? confirm = true;
    if (needsConfirm) {
      confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Log Out',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: const Text('Are you sure you want to log out?',
              style: TextStyle(fontSize: 14, color: Color(0xFF555555))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF888888))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log Out',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    if (confirm != true || !mounted) return;

    try {
      await _auth.signOut(); // wait until the session is fully cleared
    } catch (e) {
      _showSnackBar('Failed to log out. Please try again.', isError: true);
      return;
    }

    if (!mounted) return;

    // Remove ALL previous routes and show a fresh LoginPage
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // ── Delete Farmer ─────────────────────────────────────────────
  Future<void> _deleteFarmer(String docId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Farmer',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Are you sure you want to remove $name?',
            style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.collection('farmers').doc(docId).delete();
      _showSnackBar('$name removed successfully.', isError: true);
    }
  }

  // ── Open Scan Page for a farmer ───────────────────────────────
  void _openScan({
    required String docId,
    required String name,
    required String farmId,
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => ScanPage(
          farmerName: name,
          farmId: farmId,
          farmerDocId: docId,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  void _openNewFarmer() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const NewFarmerPage(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? Colors.redAccent : const Color(0xFF11BD51),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final displayName = user?.displayName ?? 'Grader';

    // canPop: false → the Back button can never leave the dashboard
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: AppDrawer(onLogout: _logout),
        backgroundColor: const Color(0xFFE8F8EF),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Collapsible header (shrinks as the sheet is dragged up) ──
              AnimatedBuilder(
                animation: _sheetController,
                builder: (context, child) {
                  final progress = _sheetController.value;
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: 1.0 - progress,
                      child: Opacity(
                        opacity: (1.0 - progress * 1.4).clamp(0.0, 1.0),
                        child: child,
                      ),
                    ),
                  );
                },
                child: Column(
                  key: _headerKey,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top App Bar ───────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          // Hamburger button
                          GestureDetector(
                            onTap: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                            child: Container(
                              width: 40,
                              height: 40,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2))
                                ],
                              ),
                              child: const Icon(Icons.menu,
                                  size: 20, color: Color(0xFF1A1A1A)),
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFF11BD51), width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset('assets/images/logo.png',
                                  width: 40, height: 40, fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text('CaneVision',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A))),
                          const Spacer(),
                          GestureDetector(
                            onTap: _logout,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2))
                                ],
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.logout,
                                      size: 16, color: Colors.redAccent),
                                  SizedBox(width: 5),
                                  Text('Logout',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Welcome ───────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text('Welcome, $displayName!',
                          style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF444444),
                              fontWeight: FontWeight.w500)),
                    ),

                    const SizedBox(height: 14),

                    // ── Stats Row ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore.collection('farmers').snapshots(),
                        builder: (context, snapshot) {
                          final docs = snapshot.hasData
                              ? snapshot.data!.docs
                              : <QueryDocumentSnapshot>[];
                          final count = docs.length;

                          // Grade → numeric rank (FA best=1, FF worst=6)
                          const gradeRank = {
                            'FA': 1, 'FB': 2, 'FC': 3,
                            'FD': 4, 'FE': 5, 'FF': 6,
                          };
                          const rankToGrade = {
                            1: 'FA', 2: 'FB', 3: 'FC',
                            4: 'FD', 5: 'FE', 6: 'FF',
                          };

                          // Only farmers with a real grade assigned
                          final graded = docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final g = (data['grade'] ?? '--')
                                .toString()
                                .toUpperCase();
                            return gradeRank.containsKey(g);
                          }).toList();

                          String avgGrade = '--';
                          if (graded.isNotEmpty) {
                            final total = graded.fold<int>(0, (sum, doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final g = (data['grade'] ?? '')
                                  .toString()
                                  .toUpperCase();
                              return sum + (gradeRank[g] ?? 0);
                            });
                            final avg =
                                (total / graded.length).round().clamp(1, 6);
                            avgGrade = rankToGrade[avg] ?? '--';
                          }

                          return Row(
                            children: [
                              _buildStatCard(
                                  label: "Today's Score",
                                  value: '--',
                                  showArrow: false),
                              const SizedBox(width: 10),
                              _buildStatCard(
                                  label: 'Avg Grade',
                                  value: avgGrade,
                                  showArrow: avgGrade != '--'),
                              const SizedBox(width: 10),
                              _buildStatCard(
                                  label: 'Farmers',
                                  value: count.toString(),
                                  showArrow: false),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Farmers (single) tab button ───────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildFarmersHeaderButton(),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // ── White Card (with drag handle) ─────────────────────
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildDragHandle(),
                      Expanded(child: _buildFarmersTab()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Drag Handle ───────────────────────────────────────────────
  Widget _buildDragHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleSheet,
      onVerticalDragStart: _onHandleDragStart,
      onVerticalDragUpdate: _onHandleDragUpdate,
      onVerticalDragEnd: _onHandleDragEnd,
      child: SizedBox(
        width: double.infinity,
        height: 28, // generous touch target
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD5D5D5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  // ── The single "Farmers" header button (always active) ────────
  Widget _buildFarmersHeaderButton() {
    return Container(
      height: 46,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
        border: Border.all(color: const Color(0xFF11BD51), width: 1.5),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 18, color: Color(0xFF11BD51)),
          SizedBox(width: 6),
          Text('Farmers',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A))),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // FARMERS TAB — registered list (with Scan button) + New Farmer
  // ════════════════════════════════════════════════════════════════
  Widget _buildFarmersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, 2),
          child: Text('Select Farmer',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A))),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text('Choose whose sugarcane will you be scanning',
              style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
        ),

        const SizedBox(height: 14),

        // Registered / New Farmer pill toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _buildFarmerTabPill(
                  label: 'Registered Farmers',
                  isActive: true,
                  onTap: () {},
                ),
                _buildFarmerTabPill(
                  label: 'New Farmer',
                  isActive: false,
                  onTap: _openNewFarmer,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Expanded(child: _buildRegisteredList()),
      ],
    );
  }

  // ── Registered Farmer List ────────────────────────────────────
  Widget _buildRegisteredList() {
    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchController,
            style:
                const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A)),
            decoration: InputDecoration(
              hintText: 'Search by name, Farm ID, or phone',
              hintStyle:
                  const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
              prefixIcon: const Icon(Icons.search,
                  color: Color(0xFFBBBBBB), size: 18),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('farmers')
                .orderBy('createdAt', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF11BD51), strokeWidth: 2.5));
              }
              if (snapshot.hasError) {
                return const Center(
                    child: Text('Error loading farmers',
                        style: TextStyle(color: Color(0xFF888888))));
              }

              final docs = snapshot.data?.docs ?? [];
              final filtered = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name =
                    (data['fullName'] ?? '').toString().toLowerCase();
                final farmId =
                    (data['farmId'] ?? '').toString().toLowerCase();
                final phone =
                    (data['phone'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) ||
                    farmId.contains(_searchQuery) ||
                    phone.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 44, color: Color(0xFFCCCCCC)),
                      SizedBox(height: 10),
                      Text('No farmers yet',
                          style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFFAAAAAA),
                              fontWeight: FontWeight.w500)),
                      SizedBox(height: 4),
                      Text('Tap "New Farmer" to add one',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFFCCCCCC))),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 4),
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFF0F0F0)),
                itemBuilder: (context, index) {
                  final doc = filtered[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildFarmerTile(
                    docId: doc.id,
                    name: data['fullName'] ?? '',
                    farmId: data['farmId'] ?? '',
                    phone: data['phone'] ?? '',
                    email: data['email'] ?? '',
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Shared Widgets ────────────────────────────────────────────
  Widget _buildStatCard({
    required String label,
    required String value,
    required bool showArrow,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: Color(0xFF888888))),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A))),
                if (showArrow) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_outward,
                      size: 13, color: Color(0xFF11BD51)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmerTabPill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 4,
                        offset: const Offset(0, 1))
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFF888888))),
        ),
      ),
    );
  }

  // Farmer row: details on the left, Scan button + Delete on the right
  Widget _buildFarmerTile({
    required String docId,
    required String name,
    required String farmId,
    required String phone,
    required String email,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text('Farm ID: $farmId',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF888888))),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined,
                        size: 11, color: Color(0xFF888888)),
                    const SizedBox(width: 3),
                    Text(phone,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF888888))),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.email_outlined,
                          size: 11, color: Color(0xFF888888)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(email,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF888888))),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Scan button (replaces the old grade badge)
          GestureDetector(
            onTap: () =>
                _openScan(docId: docId, name: name, farmId: farmId),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF11BD51),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt_outlined,
                      size: 13, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Scan',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _deleteFarmer(docId, name),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.delete_outline,
                  size: 15, color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}