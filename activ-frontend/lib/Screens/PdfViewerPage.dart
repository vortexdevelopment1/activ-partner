import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import '../Style/app_colors.dart';
import '../Style/app_size.dart';
import 'CommonCode.dart';

class PdfViewerPage extends StatefulWidget {
  final File pdfFile;
  String documentType = "";

  PdfViewerPage(this.pdfFile, this.documentType);

  @override
  _PdfViewerPageState createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  int currentPage = 0;
  int pageCount = 0;

  @override
  Widget build(BuildContext context) {
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: AppColors.white,
      ),
      child: Container(
        child: Stack(
          children: [
            /*To Set Top Header Color*/
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 100,
                color: AppColors.white,
              ),
            ),
        
            /*To Set Bottom Header Color*/
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 100,
                color: AppColors.white,
              ),
            ),
            SafeArea(
              top: true,
              bottom: true,
              left: false,
              right: false,
              child: Scaffold(
                backgroundColor: AppColors.white,
                body: Column(
                  children: [
                    getToolTab(context),
                    Expanded(
                      child: PDFView(
                        filePath: widget.pdfFile.path,
                        onPageChanged: (int? page, int? total) {
                          setState(() {
                            currentPage = page ?? 0;
                            pageCount = total ?? 0;
                          });
                        },
                      ),
                    ),

                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        "Page No ${currentPage + 1} / $pageCount",
                        style: TextStyle(
                          fontSize: AppSize.size_16,
                          fontFamily: 'FontSemiBold',
                        ),
                      ),
                    ),

                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      child: Column(
                        children: [
                          bottomBarShadow(),

                          Row(
                            children: [
                              Expanded(
                                  flex: 1,
                                  child: InkWell(
                                      onTap: ()
                                      {
                                        Navigator.pop(context);
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 10),
                                          child: getBackButton(context, "Back", "pdfView")))
                              ),

                            ],

                          )
                        ],
                      ),
                    ),

                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget getToolTab(BuildContext context) {
    return Container(
      height: 52,
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
