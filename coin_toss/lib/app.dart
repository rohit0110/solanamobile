
import 'package:coin_toss/core/theme/app_theme.dart';
import 'package:coin_toss/features/coin_toss/presentation/coin_toss_page.dart';
import 'package:coin_toss/features/profile/data/profile_storage_service.dart';
import 'package:coin_toss/features/profile/presentation/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileStorageService = ref.watch(profileStorageServiceProvider);
    final player = profileStorageService.getPlayer();

    return MaterialApp(
      title: 'Coin Toss',
      theme: AppTheme.darkTheme,
      home: player != null ? const CoinTossPage() : ProfilePage(),
    );
  }
}
