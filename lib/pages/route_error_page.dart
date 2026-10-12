import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:animori/bean/settings/settings_detail_scaffold.dart';
import 'package:animori/bean/widget/error_widget.dart';
import 'package:animori/bean/widget/state_presentation.dart';

class RouteErrorPage extends StatelessWidget {
  const RouteErrorPage({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: const Text('Animori'),
      body: GeneralErrorWidget(
        title: '无法打开页面',
        errMsg: message,
        actions: [
          StateActionButton(
            onPressed: () => context.navigate('/tab/popular/'),
            icon: Icons.home_outlined,
            text: '返回首页',
          ),
        ],
      ),
    );
  }
}
