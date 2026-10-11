import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Shows the grades recorded by the logged-in grader
/// (reads the `grades` collection, filtered by `graderUid`).
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _gradeFilter = 'All';

  static const _grades = ['All', 'FA', 'FB', 'FC', 'FD', 'FE', 'FF'];

  static const Map<String, Color> _gradeColors = {
    'FA': Color(0xFF27AE60),
    'FB': Color(0xFF2ECC71),
    'FC': Color(0xFFF39C12),
    'FD': Color(0xFFE67E22),
    'FE': Color(0xFFE74C3C),
    'FF': Color(0xFF922B21),
  };

  @override
  void initState() {
    super.initState();
    _search.addListener(
        () => setState(() => _query = _search.text.toLowerCase()));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return 'Just now';
    final d = ts.toDate();
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final min = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${m[d.month - 1]} ${d.day}, ${d.year} • $hour12:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFE8F8EF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
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
                      child: const Icon(Icons.arrow_back_ios_new,
                          size: 16, color: Color(0xFF1A1A1A)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Grading History',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A))),
                ],
              ),
            ),

            // ── White card ────────────────────────────────────────
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
                    const SizedBox(height: 16),
                    // Search
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: _search,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF1A1A1A)),
                        decoration: InputDecoration(
                          hintText: 'Search by farmer, Farm ID, or cert ID',
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
                    const SizedBox(height: 10),

                    // Grade filter chips
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _grades.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final g = _grades[i];
                          final active = _gradeFilter == g;
                          return GestureDetector(
                            onTap: () => setState(() => _gradeFilter = g),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFF11BD51)
                                    : const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(g,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: active
                                          ? Colors.white
                                          : const Color(0xFF666666))),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // List
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        // No orderBy here on purpose: where + orderBy on a
                        // different field needs a composite index. We sort
                        // on the device instead.
                        stream: FirebaseFirestore.instance
                            .collection('grades')
                            .where('graderUid', isEqualTo: uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFF11BD51),
                                    strokeWidth: 2.5));
                          }
                          if (snapshot.hasError) {
                            return Center(
                                child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                  'Could not load history.\n${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF888888))),
                            ));
                          }

                          final docs = [...?snapshot.data?.docs];
                          docs.sort((a, b) {
                            final ta = a.data()['createdAt'] as Timestamp?;
                            final tb = b.data()['createdAt'] as Timestamp?;
                            // null = pending server timestamp → newest
                            if (ta == null && tb == null) return 0;
                            if (ta == null) return -1;
                            if (tb == null) return 1;
                            return tb.compareTo(ta);
                          });

                          final filtered = docs.where((doc) {
                            final d = doc.data();
                            final grade =
                                (d['grade'] ?? '').toString().toUpperCase();
                            if (_gradeFilter != 'All' &&
                                grade != _gradeFilter) {
                              return false;
                            }
                            if (_query.isEmpty) return true;
                            return (d['farmerName'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .contains(_query) ||
                                (d['farmId'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .contains(_query) ||
                                (d['certId'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .contains(_query);
                          }).toList();

                          if (filtered.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.history,
                                      size: 44, color: Color(0xFFCCCCCC)),
                                  const SizedBox(height: 10),
                                  Text(
                                      docs.isEmpty
                                          ? 'No grading history yet'
                                          : 'No matching records',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFFAAAAAA),
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  Text(
                                      docs.isEmpty
                                          ? 'Grades you issue will show up here'
                                          : 'Try a different search or filter',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFCCCCCC))),
                                ],
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 4, 20, 4),
                                child: Text(
                                    '${filtered.length} record${filtered.length == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF888888))),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 4),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const Divider(
                                      height: 1, color: Color(0xFFF0F0F0)),
                                  itemBuilder: (_, i) =>
                                      _buildTile(filtered[i].data()),
                                ),
                              ),
                            ],
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

  Widget _buildTile(Map<String, dynamic> d) {
    final grade = (d['grade'] ?? '--').toString().toUpperCase();
    final color = _gradeColors[grade] ?? const Color(0xFF888888);
    return InkWell(
      onTap: () => _showDetails(d),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((d['farmerName'] ?? '').toString(),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 2),
                  Text('Farm ID: ${d['farmId'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF888888))),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 11, color: Color(0xFF888888)),
                      const SizedBox(width: 3),
                      Text(_formatDate(d['createdAt'] as Timestamp?),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF888888))),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(grade,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }

  void _showDetails(Map<String, dynamic> d) {
    final grade = (d['grade'] ?? '--').toString().toUpperCase();
    final color = _gradeColors[grade] ?? const Color(0xFF888888);
    final photo = (d['photoUrl'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(grade,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((d['quality'] ?? '').toString(),
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A))),
                        Text((d['certId'] ?? '').toString(),
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF888888))),
                      ],
                    ),
                  ),
                ],
              ),
              if (photo.isNotEmpty) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    photo,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 100,
                      color: const Color(0xFFF0FBF5),
                      child: const Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: Color(0xFF11BD51))),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _row('Farmer', (d['farmerName'] ?? '').toString()),
              _row('Farm ID', (d['farmId'] ?? '').toString()),
              _row('Trash Discount', '${d['trashDiscount'] ?? 0}%'),
              _row('Remarks',
                  '${d['remarkCode'] ?? ''} – ${d['remarkFull'] ?? ''}'),
              _row('Date', _formatDate(d['createdAt'] as Timestamp?)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
}