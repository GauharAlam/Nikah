import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/ward_profile.dart';

/// Builds a one-page biodata a member can send to families. No photo, and no
/// phone number unless the member chooses to add it.
class BiodataPdf {
  BiodataPdf._();

  /// The rows printed, so what is shared can be tested without reading a PDF.
  static List<(String, String)> rows(WardProfile p, {required bool includePhone}) {
    final List<(String, String)> all = <(String, String)>[
      ('Name', p.displayName),
      ('Age', p.age?.toString() ?? ''),
      ('Height', p.height),
      ('Marital status', p.maritalStatus),
      ('Children', p.children),
      ('Lives in', <String>[p.city, p.homeState, p.country].where((String s) => s.isNotEmpty).join(', ')),
      ('Education', p.qualification),
      ('University', p.almaMaters.join(', ')),
      ('Profession', p.profession),
      ('Company', p.company),
      ('Sect', p.sect == 'Prefer not to say' ? '' : p.sect),
      ('Caste', p.showCaste && p.caste != 'Prefer not to say' ? p.caste : ''),
      ('Marriage plans', p.marriageReadiness),
      if (includePhone) ('Contact', p.e164Phone),
    ];
    return all.where(((String, String) r) => r.$2.isNotEmpty).toList();
  }

  /// The built-in PDF font covers Latin text only.
  static String _printable(String text) =>
      text.replaceAll(RegExp(r'[^\x20-\x7E -ÿ]'), '');

  static Future<Uint8List> build(
    WardProfile p, {
    required String appName,
    required String link,
    bool includePhone = false,
  }) {
    const PdfColor green = PdfColor.fromInt(0xFF185A42);
    final pw.Document doc = pw.Document(title: 'Biodata');
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text('Biodata', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: green)),
          pw.SizedBox(height: 18),
          for (final (String label, String value) in rows(p, includePhone: includePhone))
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 9),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: <pw.Widget>[
                  pw.SizedBox(width: 130, child: pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700))),
                  pw.Expanded(child: pw.Text(_printable(value))),
                ],
              ),
            ),
          if (p.aboutMe.trim().isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 12),
            pw.Text('About', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: green)),
            pw.SizedBox(height: 5),
            pw.Text(_printable(p.aboutMe)),
          ],
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey400),
          pw.Text('Made with $appName  |  $link', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ],
      ),
    ));
    return doc.save();
  }
}
