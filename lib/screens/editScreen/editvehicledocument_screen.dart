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

class EditVehicleDocumentScreen extends StatelessWidget {
  final String? status;
  const EditVehicleDocumentScreen({Key? key, this.status}) : super(key: key);
  ////pending rejected approve
  @override
  Widget build(BuildContext context) {
    print('testing  ${status}');
    return Scaffold(
      backgroundColor: ColorResources.backgroundColor,
      appBar: AppBar(
        title: Text("Edit Document"),
        leading: GestureDetector(
          onTap: () {
            Get.back();
          },

          child: Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: GetBuilder<AuthController>(
        builder: (controller) {
          final canEditDriver = controller.isAnyDriverRejected;
          final canEditVehicle = controller.isAnyVehicleRejected;
          if (controller.isDocLoading) {
            return Center(child: PremiumBlurLoader());
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
                    "Data Not Found",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
            // return const Center(child: Text("Data Not Found"));
          }

          return SingleChildScrollView(
            //padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                /// ================= DRIVER BIG CARD =================
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
                          (index) => documentCard(
                            controller.editDriverDocumentList[index],
                            controller,
                            index,
                            true,
                            canEditDriver,
                          ),
                        ),

                        const SizedBox(height: 10),
                        if (controller.isAnyDriverRejected)
                          CustomPrimaryButton(
                            text: "Update Driver Document",
                            onTap: () async {
                              // await controller.updateDriverDocument(
                              //   context: context,
                              //   documents: controller.editDriverDocumentList,
                              // );
                              try {
                                showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) =>  PremiumBlurLoader(),
                            );

                                await controller.updateDriverDocument(
                                  context: context,
                                  documents: controller.editDriverDocumentList,
                                );
                              } catch (e) {
                                debugPrint('updateDriverDocument Error: $e');
                              } finally {
                                if (Get.isDialogOpen ?? false) {
                                  Get.back();
                                }
                              }
                            },
                          ),
                      ],
                    ),
                  ),

                /// ================= VEHICLE BIG CARD =================
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
                          (index) => documentCard(
                            controller.editVehicleDocumentList[index],
                            controller,
                            index,
                            false,
                            canEditVehicle,
                          ),
                        ),

                        const SizedBox(height: 10),
                        if (controller.isAnyVehicleRejected)
                          CustomPrimaryButton(
                            text: "Update Vehicle Document",
                            onTap: () async {
                              try {
                               showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) =>  PremiumBlurLoader(),
                            );

                                await controller.updateVehicleDocument(
                                  context: context,
                                  documents: controller.editVehicleDocumentList,
                                );
                              } catch (e) {
                                debugPrint('updateVehicleDocument Error: $e');
                              } finally {
                                if (Get.isDialogOpen ?? false) {
                                  Get.back();
                                }
                              }

                              // await controller.updateVehicleDocument(
                              //   context: context,
                              //   documents: controller.editVehicleDocumentList,
                              // );
                            },
                          ),
                      ],
                    ),
                  ),
                SizedBox(height: Dimensions.smallSize),

                CustomPrimaryButton(
                  text: "Back To Login",
                  onTap: () async {
                    Get.toNamed(RouteHelper.getLoginRoute());
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget documentCard(
    EditVehicleDocumentsModel doc,
    AuthController controller,
    int index,
    bool isDriver,
    bool canEdit,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 18),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            //  doc.status == "rejected"
            //     ? ColorResources.redbuttoncolor
            //     :
            ColorResources.whiteColor,
        // color: Colors.white,
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
          /// Name + Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                doc.name ?? "",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: doc.status == "rejected"
                      ? ColorResources.buttonColors
                      : ColorResources.whiteColor,
                  // Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  doc.status ?? "",
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            ],
          ),

          SizedBox(height: 10),

          /// IMAGE
          GestureDetector(
            onTap: () => controller.pickImage(index, isDriver),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.grey.shade200,
              ),
              child: doc.imageFiles != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(doc.imageFiles!, fit: BoxFit.cover),
                    )
                  : doc.file != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        ApiConstants.fileUrl + doc.file!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt),
                          SizedBox(height: 5),
                          Text("Upload Document"),
                        ],
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 12),

          /// Document Number
          TextFormField(
            controller: doc.numberControllers,
            readOnly: !canEdit,
            decoration: InputDecoration(
              labelText: "Document Number",
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: doc.status == "rejected" ? Colors.red : Colors.grey,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          if (doc.expiryControllers.text.trim().isNotEmpty)
            Column(
              children: [
                const SizedBox(height: 12),

                TextFormField(
                  controller: doc.expiryControllers,
                  readOnly: true,
                  onTap: canEdit
                      ? () => controller.pickDate(index, isDriver)
                      : null,
                  decoration: InputDecoration(
                    labelText: "Expiry Date",
                    suffixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: doc.status == "rejected"
                            ? Colors.red
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),

          // TextFormField(
          //   controller: doc.expiryControllers,
          //   readOnly: true,
          //   onTap: canEdit ? () => controller.pickDate(index, isDriver) : null,
          //   decoration: InputDecoration(
          //     labelText: "Expiry Date",
          //     suffixIcon: Icon(Icons.calendar_today),
          //     border: OutlineInputBorder(
          //       borderSide: BorderSide(
          //         color: doc.status == "rejected" ? Colors.red : Colors.grey,
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
