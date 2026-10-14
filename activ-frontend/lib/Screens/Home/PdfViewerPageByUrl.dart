import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../Style/app_colors.dart';
import '../../Style/app_size.dart';
import '../CommonCode.dart';


class PdfViewerPageByUrl extends StatefulWidget {
  final String pdfUrl; //  Firebase URL
  final String documentType;

  PdfViewerPageByUrl(this.pdfUrl, this.documentType);

  @override
  _State createState() => _State();
}

class _State extends State<PdfViewerPageByUrl> {
  int currentPage = 0;
  int pageCount = 0;
  File? pdfFile;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    try {
      final response = await http.get(Uri.parse(widget.pdfUrl));
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/temp_pdf.pdf');

      await file.writeAsBytes(response.bodyBytes);

      setState(() {
        pdfFile = file;
        isLoading = false;
      });
    } catch (e) {
      print("PDF Load Error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: AppColors.white,
      ),
      child: SafeArea(
        left: false,
        top: false,
        right: false,
        bottom: true,
        child: Scaffold(
          backgroundColor: AppColors.white,
          body: Column(
            children: [
              getToolTab(context),

              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : pdfFile == null
                    ? const Center(child: Text("Failed to load PDF"))
                    : PDFView(
                  filePath: pdfFile!.path,
                  onPageChanged: (int? page, int? total) {
                    setState(() {
                      currentPage = page ?? 0;
                      pageCount = total ?? 0;
                    });
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  "Page No ${currentPage + 1} / $pageCount",
                  style: TextStyle(
                    fontSize: AppSize.size_16,
                    fontFamily: 'FontSemiBold',
                  ),
                ),
              ),

              bottomBarShadow(),

              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: EdgeInsets.only(right: 5),
                    child: getBackButton(context, "Back", "pdfView")),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget getToolTab(BuildContext context) {
    return Container(
      height: 65,
      margin: EdgeInsets.only(top: 25),
      color: AppColors.white,
      alignment: Alignment.center,
      child: Text(
        widget.documentType,
        style: TextStyle(
          fontSize: AppSize.size_20,
          fontFamily: 'FontSemiBold',
          color: AppColors.darkBlack,
        ),
      ),
    );
  }
}
