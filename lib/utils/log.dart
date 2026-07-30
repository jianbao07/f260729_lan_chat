import 'package:flutter/cupertino.dart';


void iLog(dynamic msg, [String? tag]) {
  final t = tag != null ? ("myLog-${tag ?? ""}:") : "myLog:";
  debugPrint("${t.toString()}${(msg ?? "")}");
}

bool isOffDebugLog=true;
void dLog(dynamic msg, [String? tag]) {
  if(isOffDebugLog){
    return;
  }
  final t = tag != null ? ("myLog-${tag ?? ""}:") : "myLog:";
  debugPrint("${t.toString()}${(msg ?? "")}");
}