import 'package:get/get.dart';
import 'package:myridedriverapp/model/account_document_model.dart';

class DocumentsController extends GetxController {

  var documents = <DocumentModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadDocuments();
  }

  void loadDocuments() {
    documents.value = [
      DocumentModel(title: "Document 1", isApproved: true),
      DocumentModel(title: "Document 2", isApproved: true),
      DocumentModel(title: "Document 3", isApproved: false),
      DocumentModel(title: "Document 4", isApproved: true),
    ];
  }
}