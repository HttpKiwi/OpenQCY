import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ble_controller.dart';

final bleControllerProvider = ChangeNotifierProvider<BleController>((ref) {
  final controller = BleController();
  ref.onDispose(controller.dispose);
  return controller;
});
