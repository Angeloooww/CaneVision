import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedTab = 0; // 0 = Dashboard, 1 = Farmers, 2 = Graders

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Farmers tab search
  final TextEditingController _farmerSearchController = TextEditingController();
  String _farmerQuery = '';

  @override
  void initState() {
    super.initState();
    _farmerSearchController.addListener(() {
      setState(() => _farmerQuery = _farmerSearchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _farmerSearchController.dispose();
    super.dispose();
  }

  // Grade color map
  Color _gradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'FA': return const Color(0xFF27AE60);
      case 'FB': return const Color(0xFF2ECC71);
      case 'FC': return const Color(0xFFF39C12);
      case 'FD': return const Color(0xFFE67E22);
      case 'FE': return const Color(0xFFE74C3C);
      case 'FF': return const Color(0xFF922B21);
      default:   return const Color(0xFFAAAAAA);
    }
  }

  // ── Logout ─────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    if (confirm == true) await _auth.signOut();
  }

  // ── Delete Farmer ──────────────────────────────────────────────
  Future<void> _deleteFarmer(String docId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Farmer',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Remove $name from the system?',
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
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.collection('farmers').doc(docId).delete();
      _showSnackBar('$name removed.', isError: true);
    }
  }

  // ── Delete Grader ──────────────────────────────────────────────
  Future<void> _deleteGrader(String docId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Grader',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Remove $name from the system?\n\nNote: This removes their Firestore record. Their Firebase Auth account will remain until deleted from the Firebase console.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF444444))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.collection('users').doc(docId).delete();
      _showSnackBar('$name removed.', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : const Color(0xFF11BD51),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final adminName =
        _auth.currentUser?.displayName ?? 'Admin';

    return Scaffold(
      backgroundColor: const Color(0xFFE8F8EF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top App Bar ────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
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
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('CaneVision',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A))),
                  const Spacer(),
                  // Admin badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A4A4A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('ADMIN',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 8),
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

            // ── Welcome ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Welcome, $adminName!',
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF444444),
                      fontWeight: FontWeight.w500)),
            ),

            const SizedBox(height: 14),

            // ── Tab Buttons ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      label: 'Dashboard',
                      icon: Icons.dashboard_outlined,
                      isActive: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTabButton(
                      label: 'Farmers',
                      icon: Icons.grass_outlined,
                      isActive: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTabButton(
                      label: 'Admins',
                      icon: Icons.people_outline,
                      isActive: _selectedTab == 2,
                      onTap: () => setState(() => _selectedTab = 2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTabButton(
                      label: 'Grades',
                      icon: Icons.workspace_premium_outlined,
                      isActive: _selectedTab == 3,
                      onTap: () => setState(() => _selectedTab = 3),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Content Card ───────────────────────────────────────
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
                child: _selectedTab == 0
                    ? _buildDashboard()
                    : _selectedTab == 1
                        ? _buildFarmersTab()
                        : _selectedTab == 2
                            ? _buildGradersTab()
                            : _buildRecentGradesTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DASHBOARD TAB
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDashboard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('farmers').snapshots(),
      builder: (context, farmersSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('users').snapshots(),
          builder: (context, usersSnap) {
            final farmers =
                farmersSnap.hasData ? farmersSnap.data!.docs : <QueryDocumentSnapshot>[];
            final users =
                usersSnap.hasData ? usersSnap.data!.docs : <QueryDocumentSnapshot>[];

            final graders = users
                .where((u) =>
                    (u.data() as Map<String, dynamic>)['role'] == 'Grader')
                .toList();
            final admins = users
                .where((u) =>
                    (u.data() as Map<String, dynamic>)['role'] == 'Admin')
                .toList();

            // Grade distribution
            final Map<String, int> gradeCounts = {
              'FA': 0, 'FB': 0, 'FC': 0,
              'FD': 0, 'FE': 0, 'FF': 0,
            };
            for (final doc in farmers) {
              final data = doc.data() as Map<String, dynamic>;
              final g = (data['grade'] ?? '--').toString().toUpperCase();
              if (gradeCounts.containsKey(g)) gradeCounts[g] = gradeCounts[g]! + 1;
            }
            final gradedCount =
                gradeCounts.values.fold(0, (a, b) => a + b);

            // Average grade
            const gradeRank = {
              'FA': 1, 'FB': 2, 'FC': 3,
              'FD': 4, 'FE': 5, 'FF': 6,
            };
            const rankToGrade = {
              1: 'FA', 2: 'FB', 3: 'FC',
              4: 'FD', 5: 'FE', 6: 'FF',
            };
            String avgGrade = '--';
            if (gradedCount > 0) {
              final total = farmers.fold<int>(0, (sum, doc) {
                final data = doc.data() as Map<String, dynamic>;
                final g = (data['grade'] ?? '').toString().toUpperCase();
                return sum + (gradeRank[g] ?? 0);
              });
              final graded = farmers.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return gradeRank.containsKey(
                    (data['grade'] ?? '').toString().toUpperCase());
              }).length;
              if (graded > 0) {
                final avg = (total / graded).round().clamp(1, 6);
                avgGrade = rankToGrade[avg] ?? '--';
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Overview',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 4),
                  const Text('System-wide statistics at a glance',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF888888))),

                  const SizedBox(height: 16),

                  // ── Stats Grid ──────────────────────────────────
                  Row(
                    children: [
                      _buildStatCard(
                          icon: Icons.grass_outlined,
                          label: 'Total Farmers',
                          value: farmers.length.toString(),
                          color: const Color(0xFF11BD51)),
                      const SizedBox(width: 10),
                      _buildStatCard(
                          icon: Icons.people_outline,
                          label: 'Total Graders',
                          value: graders.length.toString(),
                          color: const Color(0xFF3498DB)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildStatCard(
                          icon: Icons.manage_accounts_outlined,
                          label: 'Admins',
                          value: admins.length.toString(),
                          color: const Color(0xFF9B59B6)),
                      const SizedBox(width: 10),
                      _buildStatCard(
                          icon: Icons.grading_outlined,
                          label: 'Avg Grade',
                          value: avgGrade,
                          color: _gradeColor(avgGrade)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Grade Distribution ──────────────────────────
                  const Text('Grade Distribution',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 4),
                  Text(
                      '$gradedCount of ${farmers.length} farmers have been graded',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF888888))),

                  const SizedBox(height: 14),

                  if (farmers.isEmpty)
                    _buildEmptyState(
                        icon: Icons.bar_chart,
                        message: 'No grade data yet',
                        sub: 'Grades will appear here once scans are done')
                  else
                    Column(
                      children: gradeCounts.entries.map((entry) {
                        final grade = entry.key;
                        final count = entry.value;
                        final pct = farmers.isEmpty
                            ? 0.0
                            : count / farmers.length;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              // Grade badge
                              Container(
                                width: 34,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: _gradeColor(grade),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Text(grade,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ),
                              const SizedBox(width: 10),
                              // Bar
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 10,
                                    backgroundColor:
                                        const Color(0xFFF0F0F0),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        _gradeColor(grade)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Count
                              SizedBox(
                                width: 28,
                                child: Text('$count',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF444444))),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 24),

                  // ── Recent Farmers ──────────────────────────────
                  const Text('Recent Farmers',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 12),

                  if (farmers.isEmpty)
                    _buildEmptyState(
                        icon: Icons.people_outline,
                        message: 'No farmers registered',
                        sub: 'Farmers will appear here once added')
                  else
                    ...farmers.take(5).map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildFarmerRow(
                        name: data['fullName'] ?? '',
                        farmId: data['farmId'] ?? '',
                        grade: data['grade'] ?? '--',
                        showDelete: false,
                        docId: doc.id,
                      );
                    }),

                  if (farmers.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('View all farmers',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF11BD51),
                                    fontWeight: FontWeight.w600)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward,
                                size: 14, color: Color(0xFF11BD51)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FARMERS TAB
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFarmersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 2),
          child: Text('All Farmers',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A))),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text('Manage registered farmers',
              style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _farmerSearchController,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A)),
            decoration: InputDecoration(
              hintText: 'Search by name, Farm ID, phone, or email',
              hintStyle:
                  const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
              prefixIcon: const Icon(Icons.search,
                  color: Color(0xFFBBBBBB), size: 18),
              suffixIcon: _farmerQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close,
                          color: Color(0xFFBBBBBB), size: 18),
                      onPressed: () {
                        _farmerSearchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.grey.withOpacity(0.15), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFF11BD51), width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('farmers')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF11BD51), strokeWidth: 2.5));
              }
              if (snapshot.hasError) {
                return _buildEmptyState(
                    icon: Icons.error_outline,
                    message: 'Error loading farmers',
                    sub: 'Please try again later');
              }

              final docs = snapshot.data?.docs ?? [];

              final filtered = _farmerQuery.isEmpty
                  ? docs
                  : docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name =
                          (data['fullName'] ?? '').toString().toLowerCase();
                      final farmId =
                          (data['farmId'] ?? '').toString().toLowerCase();
                      final email =
                          (data['email'] ?? '').toString().toLowerCase();
                      final phone =
                          (data['phone'] ?? '').toString().toLowerCase();
                      return name.contains(_farmerQuery) ||
                          farmId.contains(_farmerQuery) ||
                          email.contains(_farmerQuery) ||
                          phone.contains(_farmerQuery);
                    }).toList();

              if (docs.isEmpty) {
                return _buildEmptyState(
                    icon: Icons.grass_outlined,
                    message: 'No farmers registered',
                    sub: 'Farmers will appear here once added');
              }

              if (filtered.isEmpty) {
                return _buildEmptyState(
                    icon: Icons.search_off,
                    message: 'No results for "$_farmerQuery"',
                    sub: 'Try a different name, Farm ID, phone, or email');
              }

              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFF0F0F0)),
                itemBuilder: (context, index) {
                  final doc = filtered[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildFarmerRow(
                    name: data['fullName'] ?? '',
                    farmId: data['farmId'] ?? '',
                    grade: data['grade'] ?? '--',
                    phone: data['phone'] ?? '',
                    email: data['email'] ?? '',
                    showDelete: true,
                    docId: doc.id,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // GRADERS TAB
  // ═══════════════════════════════════════════════════════════════
  Widget _buildGradersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 2),
          child: Text('User Accounts',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A))),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text('Manage graders and admin accounts',
              style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF11BD51), strokeWidth: 2.5));
              }
              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return _buildEmptyState(
                    icon: Icons.people_outline,
                    message: 'No users found',
                    sub: 'User accounts will appear here');
              }

              // Separate admins and graders
              final admins = docs.where((u) =>
                  (u.data() as Map<String, dynamic>)['role'] == 'Admin').toList();
              final graders = docs.where((u) =>
                  (u.data() as Map<String, dynamic>)['role'] == 'Grader').toList();

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                children: [
                  if (admins.isNotEmpty) ...[
                    _buildSectionHeader('Admins', admins.length),
                    ...admins.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final isCurrentUser =
                          doc.id == _auth.currentUser?.uid;
                      return _buildUserRow(
                        name: data['fullName'] ?? '',
                        email: data['email'] ?? '',
                        role: 'Admin',
                        orgId: data['organizationId'] ?? '',
                        docId: doc.id,
                        isCurrentUser: isCurrentUser,
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                  if (graders.isNotEmpty) ...[
                    _buildSectionHeader('Graders', graders.length),
                    ...graders.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildUserRow(
                        name: data['fullName'] ?? '',
                        email: data['email'] ?? '',
                        role: 'Grader',
                        orgId: data['organizationId'] ?? '',
                        docId: doc.id,
                        isCurrentUser: false,
                      );
                    }),
                  ],
                  if (graders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _buildEmptyState(
                          icon: Icons.person_outline,
                          message: 'No graders registered',
                          sub: 'Graders sign up from the main login screen'),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // RECENT GRADES TAB
  // ═══════════════════════════════════════════════════════════════
  Widget _buildRecentGradesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 2),
          child: Text('Recent Grades',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A))),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text('Latest sugarcane quality assessments',
              style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('grades')
                .orderBy('createdAt', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF11BD51), strokeWidth: 2.5));
              }
              if (snapshot.hasError) {
                return _buildEmptyState(
                    icon: Icons.error_outline,
                    message: 'Error loading grades',
                    sub: 'Please try again later');
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return _buildEmptyState(
                    icon: Icons.workspace_premium_outlined,
                    message: 'No grade records yet',
                    sub: 'Grade records will appear here after scans');
              }

              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFF0F0F0)),
                itemBuilder: (context, index) {
                  final data =
                      docs[index].data() as Map<String, dynamic>;
                  return _buildGradeRow(data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGradeRow(Map<String, dynamic> data) {
    final grade = (data['grade'] ?? '--').toString().toUpperCase();
    final farmerName = data['farmerName'] ?? 'Unknown Farmer';
    final farmId = data['farmId'] ?? '';
    final quality = data['quality'] ?? '';
    final graderName = data['graderName'] ?? '';
    final photoUrl = data['photoUrl'] ?? '';
    final certId = data['certId'] ?? '';
    final remarkCode = data['remarkCode'] ?? '';
    final trashDiscount = data['trashDiscount'] ?? 0;
    final ts = data['createdAt'];
    String dateStr = '';
    if (ts != null) {
      final dt = (ts as dynamic).toDate() as DateTime;
      dateStr =
          '${dt.month}/${dt.day}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return GestureDetector(
      onTap: () => _showGradeDetail(data),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _photoPlaceholder(),
                    )
                  : _photoPlaceholder(),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(farmerName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 2),
                  Text('Farm ID: $farmId',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF888888))),
                  if (graderName.isNotEmpty)
                    Text('Graded by: $graderName',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF888888))),
                  if (dateStr.isNotEmpty)
                    Text(dateStr,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFFAAAAAA))),
                ],
              ),
            ),
            // Grade badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _gradeColor(grade),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(grade,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                const SizedBox(height: 4),
                Text(quality,
                    style: TextStyle(
                        fontSize: 10,
                        color: _gradeColor(grade),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFF0FBF5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF11BD51).withOpacity(0.2), width: 1),
      ),
      child: const Icon(Icons.grass,
          size: 28, color: Color(0xFF11BD51)),
    );
  }

  void _showGradeDetail(Map<String, dynamic> data) {
    final grade = (data['grade'] ?? '--').toString().toUpperCase();
    final photoUrl = data['photoUrl'] ?? '';
    final ts = data['createdAt'];
    String dateStr = '';
    if (ts != null) {
      final dt = (ts as dynamic).toDate() as DateTime;
      dateStr =
          '${dt.month}/${dt.day}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Photo
            if (photoUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  photoUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FBF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 48, color: Color(0xFF11BD51)),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FBF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_outlined,
                          size: 36, color: Color(0xFFCCCCCC)),
                      SizedBox(height: 6),
                      Text('No photo available',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFFAAAAAA))),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['farmerName'] ?? '',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A))),
                      Text('Farm ID: ${data['farmId'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF888888))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _gradeColor(grade),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(grade,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text(data['quality'] ?? '',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFF0F0F0)),
            const SizedBox(height: 10),
            _detailRow('Cert ID', data['certId'] ?? ''),
            _detailRow('Remark',
                '${data['remarkCode'] ?? ''} — ${data['remarkFull'] ?? ''}'),
            _detailRow(
                'Trash Discount', '${data['trashDiscount'] ?? 0}%'),
            _detailRow('Graded By', data['graderName'] ?? ''),
            _detailRow('Grader Email', data['graderEmail'] ?? ''),
            if (dateStr.isNotEmpty) _detailRow('Date', dateStr),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF888888))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A))),
          ),
        ],
      ),
    );
  }

  // ── Shared Widgets ────────────────────────────────────────────

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
          border: isActive
              ? Border.all(color: const Color(0xFF11BD51), width: 1.5)
              : Border.all(color: Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: isActive
                    ? const Color(0xFF11BD51)
                    : const Color(0xFF888888)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFF888888))),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: color.withOpacity(0.8),
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmerRow({
    required String name,
    required String farmId,
    required String grade,
    required bool showDelete,
    required String docId,
    String phone = '',
    String email = '',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(phone,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF888888))),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF888888))),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _gradeColor(grade),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(grade,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
          if (showDelete) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _deleteFarmer(docId, name),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.delete_outline,
                    size: 15, color: Colors.redAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserRow({
    required String name,
    required String email,
    required String role,
    required String orgId,
    required String docId,
    required bool isCurrentUser,
  }) {
    final isAdmin = role == 'Admin';
    final roleColor =
        isAdmin ? const Color(0xFF9B59B6) : const Color(0xFF3498DB);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
                isAdmin
                    ? Icons.manage_accounts_outlined
                    : Icons.person_outline,
                size: 20,
                color: roleColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A))),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF11BD51).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('You',
                            style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF11BD51),
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF888888))),
                if (orgId.isNotEmpty)
                  Text('Org ID: $orgId',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF888888))),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(role,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: roleColor)),
          ),
          if (!isCurrentUser) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _deleteGrader(docId, name),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.delete_outline,
                    size: 15, color: Colors.redAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF444444))),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF666666))),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String sub,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: const Color(0xFFCCCCCC)),
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFAAAAAA),
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(sub,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFFCCCCCC))),
          ],
        ),
      ),
    );
  }
}