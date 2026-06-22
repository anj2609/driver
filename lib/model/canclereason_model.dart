class CancleReasonModel {
  String? code;
  String? message;
  List<CancleReasonListModel>? data;

  CancleReasonModel({this.code, this.message, this.data});

  CancleReasonModel.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    if (json['data'] != null) {
      data = <CancleReasonListModel>[];
      json['data'].forEach((v) {
        data!.add(new CancleReasonListModel.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['code'] = this.code;
    data['message'] = this.message;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

////////    CancleReasonListModel CancleReasonModel
class CancleReasonListModel {
  int? id;
  String? name;

  CancleReasonListModel({this.id, this.name});

  CancleReasonListModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['name'] = this.name;
    return data;
  }
}
