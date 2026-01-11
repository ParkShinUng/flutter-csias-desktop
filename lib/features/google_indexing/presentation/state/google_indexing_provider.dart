import 'package:csias_desktop/features/google_indexing/presentation/state/google_indexing_controller.dart';
import 'package:csias_desktop/features/google_indexing/presentation/state/google_indexing_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final googleIndexingProvider =
    NotifierProvider<GoogleIndexingController, GoogleIndexingState>(
  GoogleIndexingController.new,
);
