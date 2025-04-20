import 'package:provider/provider.dart';
import 'services/media_repository.dart';

final List<Provider> appProviders = [
  Provider<MediaRepository>(
    create: (_) => MediaRepository(),
  ),
  // Add other providers here (e.g., chat state, user state)
];
