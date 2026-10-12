import 'package:flutter_modular/flutter_modular.dart';
import 'package:animori/core_module.dart';
import 'package:animori/pages/index_module.dart';

final appModule = createModule(
  register: (c) {
    c
      ..module(coreModule)
      ..module(indexModule);
  },
);
