import 'package:flutter/material.dart';
import 'package:ruhr_transit/app.dart';
import 'package:ruhr_transit/core/di/injection.dart';

void main() {
  configureDependencies();
  runApp(const RuhrTransitApp());
}
