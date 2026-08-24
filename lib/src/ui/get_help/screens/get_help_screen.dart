import 'package:flutter/material.dart';

import '../widgets/get_help_sheet.dart';

class GetHelpScreen extends StatelessWidget {
  const GetHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Get Help Fast')),
      body: const SingleChildScrollView(child: GetHelpSheet()),
    );
  }
}
