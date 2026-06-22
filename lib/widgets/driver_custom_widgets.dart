import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:myridedriverapp/controllers/driverpersonal_info_screen.dart';

 /////////////// ===================  Driver persnol info ====================================== //////////////////
class PersonalStep extends StatelessWidget {
  final controller = Get.find<DriverController>();

  final nameCtrl = TextEditingController();
  final nidCtrl = TextEditingController();
  final licenseCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: "Full Name"),
          ),
          TextField(
            controller: nidCtrl,
            decoration: const InputDecoration(labelText: "NID"),
          ),
          TextField(
            controller: licenseCtrl,
            decoration:
                const InputDecoration(labelText: "Driving License"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              controller.driverData.value.fullName = nameCtrl.text;
              controller.driverData.value.nid = nidCtrl.text;
              controller.driverData.value.license = licenseCtrl.text;
              controller.nextStep();
            },
            child:  Text("Next"),
          )
        ],
      ),
    );
  }
}

///////// ============================= Documents Steps ====================================////////

class DocumentStep extends StatefulWidget {
  @override
  State<DocumentStep> createState() => _DocumentStepState();
}

class _DocumentStepState extends State<DocumentStep> {
  final controller = Get.find<DriverController>();

  final typeList = ["Aadhar", "PAN", "Other"];
  String selectedType = "Aadhar";
  final numberCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButton(
            value: selectedType,
            items: typeList
                .map((e) =>
                    DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) {
              setState(() {
                selectedType = val!;
              });
            },
          ),
          TextField(
            controller: numberCtrl,
            decoration:
                const InputDecoration(labelText: "Document Number"),
          ),
          ElevatedButton(
            onPressed: () {
              controller.addDocument(
                  selectedType, numberCtrl.text);
              numberCtrl.clear();
            },
            child: const Text("Add Document"),
          ),
          const SizedBox(height: 10),
          Obx(() => Expanded(
                child: ListView.builder(
                  itemCount:
                      controller.driverData.value.documents.length,
                  itemBuilder: (_, index) {
                    final doc = controller
                        .driverData.value.documents[index];
                    return ListTile(
                      title: Text(doc["type"]!),
                      subtitle: Text(doc["number"]!),
                    );
                  },
                ),
              )),
          ElevatedButton(
            onPressed: controller.nextStep,
            child: const Text("Next"),
          )
        ],
      ),
    );
  }
}

//////////// ========================= Preview Widgets ============================/////////////////////////////

class PreviewStep extends StatelessWidget {
  final controller = Get.find<DriverController>();

  @override
  Widget build(BuildContext context) {
    final data = controller.driverData.value;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          ListTile(
            title: const Text("Full Name"),
            subtitle: Text(data.fullName),
            trailing: Icon(Icons.edit),
            onTap: () => controller.goToStep(0),
          ),
          ListTile(
            title: const Text("Vehicle Type"),
            subtitle: Text(data.vehicleType),
            trailing: Icon(Icons.edit),
            onTap: () => controller.goToStep(1),
          ),
          const SizedBox(height: 10),
          const Text("Documents",
              style: TextStyle(fontWeight: FontWeight.bold)),
          ...data.documents.map((doc) => ListTile(
                title: Text(doc["type"]!),
                subtitle: Text(doc["number"]!),
              )),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              print("Submit All Data");
            },
            child: const Text("Submit"),
          )
        ],
      ),
    );
  }
}