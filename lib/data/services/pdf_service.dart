import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/fee_models.dart';
import '../models/salary_models.dart';
import '../models/result_models.dart';

class PdfService {
  // Generate Fee Receipt PDF Document Bytes
  static Future<Uint8List> generateFeeReceiptPdf(
    FeeReceiptModel receipt, {
    String? schoolName,
    String? campusAddress,
    String? phone,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          (schoolName != null && schoolName.isNotEmpty && schoolName != 'School')
                              ? schoolName.toUpperCase()
                              : 'INSTITUTION ACADEMY',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo900,
                          ),
                        ),
                        pw.Text(
                          campusAddress ?? 'Official Institutional Campus',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        ),
                        pw.Text(
                          phone != null && phone.isNotEmpty
                              ? 'Official Contact • Phone: $phone'
                              : 'Official Digital Records Division',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.indigo50,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: PdfColors.indigo300),
                      ),
                      child: pw.Text(
                        'OFFICIAL FEE RECEIPT',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo900,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Divider(thickness: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 16),

                // Receipt Details Meta
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('RECEIPT NO: ${receipt.receiptNo}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.Text('PAYMENT DATE: ${receipt.date.day}/${receipt.date.month}/${receipt.date.year}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('PAYMENT METHOD: ${receipt.paymentMethod}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.Text('TXN REF: ${receipt.transactionRef}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Student Info Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Student Name: ${receipt.studentName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('Admission No: ${receipt.admissionNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Class & Section: ${receipt.className}'),
                          pw.Text('Father Name: ${receipt.parentName}'),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                // Table Breakdown
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('DESCRIPTION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('AMOUNT (INR)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Amount Received Towards Academic Fees')),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('₹ ${receipt.amountPaid.toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Summary Calculation
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 250,
                      child: pw.Column(
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Previous Pending Dues:'),
                              pw.Text('₹ ${receipt.previousBalance.toStringAsFixed(2)}'),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Amount Paid Now:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                              pw.Text('₹ ${receipt.amountPaid.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Divider(),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('REMAINING BALANCE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              pw.Text('₹ ${receipt.remainingBalance.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.Spacer(),

                // Signature Area
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Computer Generated Digital Slip'),
                        pw.Text('No Physical Signature Required'),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(width: 140, height: 1, color: PdfColors.grey800),
                        pw.SizedBox(height: 4),
                        pw.Text('Authorized Accounts Officer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(schoolName ?? 'Institution Accounts Division'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // Generate Salary Slip PDF Document Bytes
  static Future<Uint8List> generateSalarySlipPdf(
    SalarySlipModel slip, {
    String? schoolName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          (schoolName != null && schoolName.isNotEmpty && schoolName != 'School')
                              ? schoolName.toUpperCase()
                              : 'INSTITUTION ACADEMY',
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                        ),
                        pw.Text('Staff Payroll & Accounts Division', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.indigo50,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: PdfColors.indigo300),
                      ),
                      child: pw.Text(
                        'FACULTY SALARY SLIP',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Divider(thickness: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 16),

                // Teacher Info
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Teacher Name: ${slip.teacherName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('Employee ID: ${slip.employeeId}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Designation: ${slip.designation}'),
                          pw.Text('Salary Month: ${slip.month}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                // Allowances & Deductions Table
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Allowances Side
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('EARNINGS & ALLOWANCES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                          pw.SizedBox(height: 6),
                          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Basic Salary:'), pw.Text('₹ ${slip.basicSalary.toStringAsFixed(2)}')]),
                          ...slip.allowances.map((a) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('${a.type}:'), pw.Text('₹ ${a.amount.toStringAsFixed(2)}')])),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 24),
                    // Deductions Side
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('DEDUCTIONS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                          pw.SizedBox(height: 6),
                          ...slip.deductions.map((d) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('${d.type}:'), pw.Text('₹ ${d.amount.toStringAsFixed(2)}')])),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 24),
                pw.Divider(thickness: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 12),

                // Net Salary Box
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('NET SALARY PAYABLE:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('₹ ${slip.netSalary.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                  ],
                ),
                pw.Spacer(),

                // Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Status: ${slip.status.name.toUpperCase()}'),
                    pw.Column(
                      children: [
                        pw.Container(width: 140, height: 1, color: PdfColors.grey800),
                        pw.SizedBox(height: 4),
                        pw.Text('Payroll Manager Signature', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // Generate Official Student Report Card PDF Document Bytes
  static Future<Uint8List> generateReportCardPdf(
    StudentResultModel result, {
    String? schoolName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(28),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          (schoolName != null && schoolName.isNotEmpty && schoolName != 'School')
                              ? schoolName.toUpperCase()
                              : 'INSTITUTION ACADEMY',
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                        ),
                        pw.Text('OFFICIAL ACADEMIC REPORT CARD', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
                        pw.Text('Academic Session: ${result.academicYear}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: result.isPassed ? PdfColors.green50 : PdfColors.red50,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: result.isPassed ? PdfColors.green400 : PdfColors.red400),
                      ),
                      child: pw.Text(
                        result.isPassed ? 'RESULT: PASS' : 'RESULT: FAIL',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: result.isPassed ? PdfColors.green900 : PdfColors.red900),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(thickness: 1, color: PdfColors.indigo900),
                pw.SizedBox(height: 12),

                // Student Meta Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Student Name: ${result.studentName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                          pw.Text('Class & Section: Class ${result.className}-${result.section}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Roll No: ${result.rollNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                          pw.Text('Exam: ${result.examTitle}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Marks Breakdown Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('SUBJECT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('MAX MARKS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('OBTAINED', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('% SCORE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('GRADE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('STATUS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center)),
                      ],
                    ),
                    ...result.subjectResults.map((s) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(s.subjectName, style: const pw.TextStyle(fontSize: 10))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${s.maxMarks.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center)),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${s.obtainedMarks.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${s.percentage.toStringAsFixed(1)}%', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center)),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(s.grade, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900), textAlign: pw.TextAlign.center)),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(s.isPassed ? 'PASS' : 'FAIL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: s.isPassed ? PdfColors.green800 : PdfColors.red800), textAlign: pw.TextAlign.center)),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 16),

                // Overall Performance Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.indigo50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.indigo200),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(children: [pw.Text('Total Score', style: const pw.TextStyle(fontSize: 9)), pw.Text('${result.totalObtainedMarks.toStringAsFixed(0)} / ${result.totalMaxMarks.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13))]),
                      pw.Column(children: [pw.Text('Percentage', style: const pw.TextStyle(fontSize: 9)), pw.Text('${result.percentage.toStringAsFixed(2)}%', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.indigo900))]),
                      pw.Column(children: [pw.Text('Overall Grade', style: const pw.TextStyle(fontSize: 9)), pw.Text(result.overallGrade, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.green800))]),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),

                // Teacher Remarks
                pw.Text('TEACHER REMARKS:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                pw.SizedBox(height: 4),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(result.teacherRemarks.isNotEmpty ? result.teacherRemarks : 'Good academic performance.', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                ),
                pw.Spacer(),

                // Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Container(width: 130, height: 1, color: PdfColors.grey800),
                        pw.SizedBox(height: 4),
                        pw.Text('Class Teacher Signature', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(width: 130, height: 1, color: PdfColors.grey800),
                        pw.SizedBox(height: 4),
                        pw.Text('Principal Signature', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  // Print or Share PDF
  static Future<void> printOrSharePdf(Uint8List pdfBytes, String title) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: title,
    );
  }
}
