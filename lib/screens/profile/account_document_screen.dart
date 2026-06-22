import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/controllers/account_document_screen.dart';
import 'package:myridedriverapp/widgets/document_custom_card.dart';


class AccountDocumentsScreen extends StatelessWidget {
  AccountDocumentsScreen({super.key});

  final DocumentsController controller =
      Get.put(DocumentsController());

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    return Scaffold(
      backgroundColor: const Color(0xffF2F2F2),
      body: SafeArea(
        child: Column(
        children: [

          /// ===== HEADER =====
          Container(
            height: height * 0.18,
            width: width,
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.05,
              vertical: height * 0.03,
            ),
            decoration: const BoxDecoration(
              color: Color(0xff2FA8CC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                /// Back
                GestureDetector(
                  onTap: () => Get.back(),
                  child: const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.arrow_back, color: Colors.black),
                  ),
                ),

                const Text(
                  "Documents",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Text("Help"),
                      Icon(Icons.keyboard_arrow_down, size: 18)
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: height * 0.02),

          /// ===== BODY =====
          Expanded(
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: width * 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    "Vehicle Documents",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "Manage work with vehicle Documents",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  SizedBox(height: height * 0.02),

                  /// Dynamic List
                  Expanded(
                    child: Obx(
                      () => ListView.builder(
                        itemCount:
                            controller.documents.length,
                        itemBuilder: (context, index) {
                          final doc =
                              controller.documents[index];
                          return DocumentCard(
                            title: doc.title,
                            isApproved: doc.isApproved,
                          );
                        },
                      ),
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
}