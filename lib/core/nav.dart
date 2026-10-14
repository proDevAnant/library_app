import 'package:flutter/material.dart';

/// Lets non-widget code (like logout) reset the screen stack.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
