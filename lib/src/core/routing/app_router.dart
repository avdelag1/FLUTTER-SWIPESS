import 'package:go_router/go_router.dart';
import '../../features/swipes/presentation/screens/swiper_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SwiperScreen(),
    ),
  ],
);
