import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'new_farmer_page.dart';
import 'scan_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedTab = 0;
  int _selectedFarmerTab = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Logout ────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Sign out from Firebase — AuthWrapper in main.dart will
      // automatically redirect to LoginPage via authStateChanges stream
      await _auth.signOut();
    }
  }

  // ── Delete Farmer ─────────────────────────────────────────────
  Future<void> _deleteFarmer(String docId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Farmer',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name removed successfully'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final displayName = user?.displayName ?? 'Grader';

    return Scaffold(
      backgroundColor: const Color(0xFFE8F8EF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top App Bar ───────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF11BD51), width: 2),
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
                  const Text(
                    'CaneVision',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A)),
                  ),
                  const Spacer(),
                  // ── Logout Button ─────────────────────────────
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

            // ── Welcome Text ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Welcome, $displayName!',
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF444444),
                    fontWeight: FontWeight.w500),
              ),
            ),

            const SizedBox(height: 14),

            // ── Stats Row ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('farmers').snapshots(),
                builder: (context, snapshot) {
                  final farmerCount =
                      snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Row(
                    children: [
                      _buildStatCard(
                          label: "Today's Score",
                          value: '--',
                          showArrow: false),
                      const SizedBox(width: 10),
                      _buildStatCard(
                          label: 'Avg Grade',
                          value: '--',
                          showArrow: true),
                      const SizedBox(width: 10),
                      _buildStatCard(
                          label: 'Farmers',
                          value: farmerCount.toString(),
                          showArrow: false),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 14),

            // ── Scan / Farmers Tab Buttons ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      label: 'Scan',
                      icon: Icons.home_outlined,
                      isActive: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTabButton(
                      label: 'Farmers',
                      icon: Icons.people_outline,
                      isActive: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── White Bottom Card ─────────────────────────────────
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 22, 20, 2),
                      child: Text(
                        'Select Farmer',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A)),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: Text(
                        'Choose whose sugarcane will you be scanning',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF888888)),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Registered Farmer / New Farmer toggle
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
                              label: 'Registered Farmer',
                              isActive: _selectedFarmerTab == 0,
                              onTap: () =>
                                  setState(() => _selectedFarmerTab = 0),
                            ),
                            _buildFarmerTabPill(
                              label: 'New Farmer',
                              isActive: _selectedFarmerTab == 1,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, animation, __) =>
                                        const NewFarmerPage(),
                                    transitionsBuilder:
                                        (_, animation, __, child) =>
                                            FadeTransition(
                                                opacity: animation,
                                                child: child),
                                    transitionDuration:
                                        const Duration(milliseconds: 250),
                                  ),
                                ).then((_) =>
                                    setState(() => _selectedFarmerTab = 0));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF1A1A1A)),
                        decoration: InputDecoration(
                          hintText: 'Search by name, Farm ID, or phone',
                          hintStyle: const TextStyle(
                              fontSize: 12, color: Color(0xFFBBBBBB)),
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

                    // ── Farmer List (real-time Firestore) ─────────
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('farmers')
                            .orderBy('createdAt', descending: false)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF27AE60),
                                  strokeWidth: 2.5),
                            );
                          }

                          if (snapshot.hasError) {
                            return const Center(
                                child: Text('Error loading farmers',
                                    style: TextStyle(
                                        color: Color(0xFF888888))));
                          }

                          final docs = snapshot.data?.docs ?? [];
                          final filtered = docs.where((doc) {
                            final data =
                                doc.data() as Map<String, dynamic>;
                            final name = (data['fullName'] ?? '')
                                .toString()
                                .toLowerCase();
                            final farmId = (data['farmId'] ?? '')
                                .toString()
                                .toLowerCase();
                            final phone = (data['phone'] ?? '')
                                .toString()
                                .toLowerCase();
                            return name.contains(_searchQuery) ||
                                farmId.contains(_searchQuery) ||
                                phone.contains(_searchQuery);
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline,
                                      size: 44,
                                      color: Color(0xFFCCCCCC)),
                                  SizedBox(height: 10),
                                  Text('No farmers yet',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFFAAAAAA),
                                          fontWeight: FontWeight.w500)),
                                  SizedBox(height: 4),
                                  Text('Tap "New Farmer" to add one',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFCCCCCC))),
                                ],
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 4),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, color: Color(0xFFF0F0F0)),
                            itemBuilder: (context, index) {
                              final doc = filtered[index];
                              final data =
                                  doc.data() as Map<String, dynamic>;
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (_, animation, __) =>
                                          ScanPage(
                                        farmerName:
                                            data['fullName'] ?? '',
                                        farmId: data['farmId'] ?? '',
                                      ),
                                      transitionsBuilder: (_,
                                              animation, __, child) =>
                                          FadeTransition(
                                              opacity: animation,
                                              child: child),
                                      transitionDuration: const Duration(
                                          milliseconds: 250),
                                    ),
                                  );
                                },
                                child: _buildFarmerTile(
                                  docId: doc.id,
                                  name: data['fullName'] ?? '',
                                  farmId: data['farmId'] ?? '',
                                  phone: data['phone'] ?? '',
                                  email: data['email'] ?? '',
                                  grade: data['grade'] ?? '--',
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stat Card ─────────────────────────────────────────────────
  Widget _buildStatCard({
    required String label,
    required String value,
    required bool showArrow,
  }) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                      size: 13, color: Color(0xFF27AE60)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Scan / Farmers Tab Button ─────────────────────────────────
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
        height: 46,
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
              ? Border.all(color: const Color(0xFF27AE60), width: 1.5)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: isActive
                    ? const Color(0xFF27AE60)
                    : const Color(0xFF888888)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFF888888))),
          ],
        ),
      ),
    );
  }

  // ── Registered / New Farmer Pill ──────────────────────────────
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

  // ── Farmer Tile ───────────────────────────────────────────────
  Widget _buildFarmerTile({
    required String docId,
    required String name,
    required String farmId,
    required String phone,
    required String email,
    required String grade,
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
                      Text(email,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF888888))),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Grade Badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF27AE60),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(grade,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
          const SizedBox(width: 8),
          // Delete Button
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