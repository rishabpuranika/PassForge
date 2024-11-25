import 'package:flutter/cupertino.dart';
import 'package:passforge/main.dart';

class SavedData{
  final String password;
  final int length;

  SavedData(this.password, this.length);

  SavedData.fromJson(Map<String, dynamic> json)
      : password = json['password'],
        length = json['length'];

  Map<String, dynamic> toJson() => {
    'password': password,
    'length': length,
  };
}

