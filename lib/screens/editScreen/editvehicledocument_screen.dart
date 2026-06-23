import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/config/route.dart';
import 'package:myridedriverapp/config/utils/colors.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:myridedriverapp/config/utils/dimensions.dart';
import 'package:myridedriverapp/controllers/auth_controller.dart';
import 'package:myridedriverapp/model/updatevehicledoc_model.dart';
import 'package:myridedriverapp/widgets/custom_button.dart';
import 'package:myridedriverapp/widgets/custom_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditVehicleDocumentScreen extends StatefulWidget {
  final String? status;
  const EditVehicleDocumentScreen({Key? key, this.status}) : super(key: key);

  @override
  State<EditVehicleDocumentScreen> createState() =>
      _EditVehicleDocumentScreenState();
}

class _EditVehicleDocumentScreenState extends State<EditVehicleDocumentScreen>
    with WidgetsBindingObserver {
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final controller = Get.find<AuthController>();
    controller.reloadDocsFromCache();
    controller.fetchDocumentStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      controller.fetchDocumentStatus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Get.find<AuthController>().fetchDocumentStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Get.offAllNamed(RouteHelper.getmyRideLoginScreen());
        }
      },
      child: Scaffold(
      backgroundColor: ColorResources.backgroundColor,
      appBar: AppBar(
        title: const Text("My Documents"),
        leading: GestureDetector(
          onTap: () => Get.offAllNamed(RouteHelper.getmyRideLoginScreen()),
          child: const Icon(Icons.arrow_back_ios_new),
        ),
        actions: [
          GetBuilder<AuthController>(
            builder: (controller) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: "Refresh status",
              onPressed: () => controller.fetchDocumentStatus(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: GetBuilder<AuthController>(
          builder: (controller) {
            if (controller.isDocLoading) {
              return const Center(child: PremiumBlurLoader());
            }

            if (controller.editDriverDocumentList.isEmpty &&
                controller.editVehicleDocumentList.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset("assets/images/notdatafound.png", height: 150),
                    const SizedBox(height: 10),
                    const Text(
                      "No documents found",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => controller.fetchDocumentStatus(),
              child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  /// ================= DRIVER DOCUMENTS =================
                  if (controller.editDriverDocumentList.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 25),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Driver Documents",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(
                            controller.editDriverDocumentList.length,
                            (index) => _documentCard(
                              context,
                              controller.editDriverDocumentList[index],
                              controller,
                              index,
                              true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (controller.isAnyDriverRejected)
                            CustomPrimaryButton(
                              text: controller.isUpdatingDriverDocs
                                  ? "Submitting..."
                                  : "Update Driver Documents",
                              onTap: controller.isUpdatingDriverDocs
                                  ? () {}
                                  : () async {
                                      try {
                                        await controller.updateDriverDocument(
                                          context: context,
                                          documents: controller.editDriverDocumentList,
                                        );
                                      } catch (e) {
                                        debugPrint('updateDriverDocument Error: $e');
                                      }
                                    },
                            ),
                        ],
                      ),
                    ),

                  /// ================= VEHICLE DOCUMENTS =================
                  if (controller.editVehicleDocumentList.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 25),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Vehicle Documents",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(
                            controller.editVehicleDocumentList.length,
                            (index) => _documentCard(
                              context,
                              controller.editVehicleDocumentList[index],
                              controller,
                              index,
                              false,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (controller.isAnyVehicleRejected)
                            CustomPrimaryButton(
                              text: controller.isUpdatingVehicleDocs
                                  ? "Submitting..."
                                  : "Update Vehicle Documents",
                              onTap: controller.isUpdatingVehicleDocs
                                  ? () {}
                                  : () async {
                                      try {
                                        await controller.updateVehicleDocument(
                                          context: context,
                                          documents: controller.editVehicleDocumentList,
                                        );
                                      } catch (e) {
                                        debugPrint('updateVehicleDocument Error: $e');
                                      }
                                    },
                            ),
                        ],
                      ),
                    ),

                  SizedBox(height: Dimensions.smallSize),
                ],
              ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }

  String _buildDocImageUrl(String? file) {
    if (file == null || file.trim().isEmpty) return '';
    // Already a full URL — use as-is
    if (file.startsWith('http://') || file.startsWith('https://')) return file;
    // Normalise: strip leading slash
    String path = file.startsWith('/') ? file.substring(1) : file;
    // API sometimes returns paths already prefixed with "storage/"
    if (path.startsWith('storage/')) {
      return '${ApiConstants.imageurl}$path';
    }
    // Otherwise prepend the full storage base URL
    final base = ApiConstants.fileUrl.endsWith('/')
        ? ApiConstants.fileUrl
        : '${ApiConstants.fileUrl}/';
    return '$base$path';
  }

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final id = (ApiConstants.userIdSocial.isNotEmpty)
        ? ApiConstants.userIdSocial
        : (prefs.getString(ApiConstants.profileid) ?? '');
    final token = (ApiConstants.userTokenSocial.isNotEmpty)
        ? ApiConstants.userTokenSocial
        : (prefs.getString(ApiConstants.token) ?? '');
    final headers = <String, String>{};
    if (id.isNotEmpty) headers['id'] = id;
    if (token.isNotEmpty) headers['authorizationToken'] = token;
    return headers;
  }

  Widget _docNetworkImage(String url) {
    if (url.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 35, color: Colors.grey),
            SizedBox(height: 5),
            Text("No image", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return FutureBuilder<Map<String, String>>(
      future: _authHeaders(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        return Image.network(
          url,
          fit: BoxFit.cover,
          headers: snap.data!.isNotEmpty ? snap.data! : null,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Doc image failed: $url — $error');
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported,
                      size: 35, color: Colors.grey),
                  SizedBox(height: 5),
                  Text(
                    "Image unavailable",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _documentCard(
    BuildContext context,
    EditVehicleDocumentsModel doc,
    AuthController controller,
    int index,
    bool isDriver,
  ) {
    final isRejected = doc.status == "rejected";
    final isPending = doc.status == "pending";

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorResources.whiteColor,
        borderRadius: BorderRadius.circular(18),
        border: isRejected
            ? Border.all(color: Colors.red.shade300, width: 1.5)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Name + Status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                doc.name ?? "",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              _statusBadge(doc.status),
            ],
          ),

          if (isRejected && (doc.remark?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 6),
            Text(
              "Reason: ${doc.remark}",
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade700,
              ),
            ),
          ],

          const SizedBox(height: 10),

          /// IMAGE
          GestureDetector(
            onTap: isRejected
                ? () => controller.pickImage(index, isDriver)
                : null,
            child: Stack(
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.grey.shade200,
                  ),
                  child: doc.imageFiles != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            doc.imageFiles!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : (doc.file != null && doc.file!.trim().isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _docNetworkImage(_buildDocImageUrl(doc.file)),
                        )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, color: Colors.grey),
                              SizedBox(height: 5),
                              Text("Upload Document",
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                ),

                /// Overlay for pending state
                if (isPending)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.hourglass_top,
                                color: Colors.white, size: 28),
                            SizedBox(height: 4),
                            Text(
                              "Under Review",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                /// Tap-to-change overlay for rejected state
                if (isRejected)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text("Re-upload",
                              style: TextStyle(
                                  color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          /// Document Number
          TextFormField(
            controller: doc.numberControllers,
            readOnly: !isRejected,
            decoration: InputDecoration(
              labelText: "Document Number",
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: isRejected ? Colors.red : Colors.grey.shade400,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color:
                      isRejected ? Colors.red : ColorResources.blueeebutton,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),

          if (doc.expiryControllers.text.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: doc.expiryControllers,
              readOnly: true,
              onTap: isRejected
                  ? () => controller.pickDate(index, isDriver)
                  : null,
              decoration: InputDecoration(
                labelText: "Expiry Date",
                suffixIcon: const Icon(Icons.calendar_today),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isRejected ? Colors.red : Colors.grey.shade400,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isRejected
                        ? Colors.red
                        : ColorResources.blueeebutton,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String? status) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case "approved":
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        label = "Approved";
        icon = Icons.check_circle_outline;
        break;
      case "rejected":
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        label = "Rejected";
        icon = Icons.cancel_outlined;
        break;
      default:
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        label = "Under Review";
        icon = Icons.hourglass_top_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
