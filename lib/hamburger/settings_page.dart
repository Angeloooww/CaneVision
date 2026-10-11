import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny helper so other pages (e.g. ScanPage) can read the saved settings.
class AppSettings {
  static const _kPhotoQuality = 'photo_quality';
  static const _kConfirmLogout = 'confirm_logout';

  static Future<int> photoQuality() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kPhotoQuality) ?? 85;
  }

  static Future<bool> confirmLogout() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kConfirmLogout) ?? true;
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _quality = 85;
  bool _confirmLogout = true;
  bool _loaded = false;

  static const String _appVersion = '1.0.0'; // update when you release

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final q = await AppSettings.photoQuality();
    final c = await AppSettings.confirmLogout();
    if (!mounted) return;
    setState(() {
      _quality = q;
      _confirmLogout = c;
      _loaded = true;
    });
  }

  Future<void> _setQuality(int v) async {
    setState(() => _quality = v);
    final p = await SharedPreferences.getInstance();
    await p.setInt(AppSettings._kPhotoQuality, v);
  }

  Future<void> _setConfirmLogout(bool v) async {
    setState(() => _confirmLogout = v);
    final p = await SharedPreferences.getInstance();
    await p.setBool(AppSettings._kConfirmLogout, v);
  }

  void _showGradeGuide() {
    const rows = [
      ['FA', '0%', 'Clean canes'],
      ['FB', '1%', 'Slight leaves'],
      ['FC', '2%', 'Moderate leaves'],
      ['FD', '3%', 'Plenty of leaves'],
      ['FE', '4%', 'Moderate leaves and plenty of cane tops'],
      ['FF', '5%', 'Dirty canes'],
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            const Text('Grade Guide',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A))),
            const SizedBox(height: 12),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 36,
                          child: Text(r[0],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF11BD51)))),
                      SizedBox(
                          width: 44,
                          child: Text(r[1],
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF888888)))),
                      Expanded(
                          child: Text(r[2],
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1A1A1A)))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F8EF),
      body: SafeArea(
        child: Column(
          children: [
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
                  const Text('Settings',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A))),
                ],
              ),
            ),
            Expanded(
              child: !_loaded
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF11BD51), strokeWidth: 2.5))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('Scanning'),
                          _card([
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text('Photo Quality',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A1A1A))),
                                  const SizedBox(height: 2),
                                  const Text(
                                      'Higher quality gives better detail but larger files',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF888888))),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _qualityChip('Low', 50),
                                      const SizedBox(width: 8),
                                      _qualityChip('Medium', 85),
                                      const SizedBox(width: 8),
                                      _qualityChip('High', 100),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ]),
                          const SizedBox(height: 20),
                          _sectionTitle('General'),
                          _card([
                            SwitchListTile(
                              value: _confirmLogout,
                              onChanged: _setConfirmLogout,
                              activeColor: const Color(0xFF11BD51),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              title: const Text('Confirm before logging out',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A))),
                              subtitle: const Text(
                                  'Show a confirmation dialog when you tap Log Out',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF888888))),
                            ),
                            const Divider(
                                height: 1, color: Color(0xFFF0F0F0)),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              leading: const Icon(Icons.workspace_premium,
                                  color: Color(0xFF11BD51)),
                              title: const Text('Grade Guide',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A))),
                              subtitle: const Text(
                                  'Trash discount and remarks per grade',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF888888))),
                              trailing: const Icon(Icons.chevron_right,
                                  color: Color(0xFFCCCCCC)),
                              onTap: _showGradeGuide,
                            ),
                          ]),
                          const SizedBox(height: 20),
                          _sectionTitle('About'),
                          _card([
                            const ListTile(
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 16),
                              leading: Icon(Icons.info_outline,
                                  color: Color(0xFF11BD51)),
                              title: Text('CaneVision',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A))),
                              subtitle: Text(
                                  'Sugarcane Grading System • v$_appVersion',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF888888))),
                            ),
                          ]),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qualityChip(String label, int value) {
    final active = _quality == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setQuality(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF11BD51) : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : const Color(0xFF666666))),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF888888))),
      );

  Widget _card(List<Widget> children) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(children: children),
      );
}