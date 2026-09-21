import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Profile-mode startup, root-navigation, and frame telemetry for DevTools.
///
/// No user data, routes, request bodies, or identifiers are emitted. Release
/// builds stay silent; profile traces expose enough timing data to verify that
/// a change improved actual device responsiveness.
class AppPerformanceMonitor {
  AppPerformanceMonitor._();

  static final instance = AppPerformanceMonitor._();
  static const _frameWindowSize = 120;
  static const _jankThreshold = Duration(milliseconds: 16);

  final List<FrameTiming> _frameWindow = [];
  Stopwatch? _launchStopwatch;
  developer.TimelineTask? _launchTask;
  developer.TimelineTask? _tabTask;
  bool _started = false;

  void startLaunch() {
    if (!kProfileMode || _started) return;
    _started = true;
    _launchStopwatch = Stopwatch()..start();
    _launchTask = developer.TimelineTask()..start('readendar.app_launch');
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  void markFirstFrame() {
    final stopwatch = _launchStopwatch;
    final task = _launchTask;
    if (!kProfileMode || stopwatch == null || task == null) return;
    stopwatch.stop();
    task.finish(arguments: {'first_frame_ms': stopwatch.elapsedMilliseconds});
    _launchTask = null;
  }

  void startRootTabTransition(int index) {
    if (!kProfileMode) return;
    _tabTask?.finish(arguments: const {'interrupted': true});
    _tabTask = developer.TimelineTask()
      ..start('readendar.root_tab_transition', arguments: {'tab': index});
  }

  void markRootTabFirstFrame(int index) {
    final task = _tabTask;
    if (!kProfileMode || task == null) return;
    task.finish(arguments: {'tab': index});
    _tabTask = null;
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!kProfileMode) return;
    _frameWindow.addAll(timings);
    if (_frameWindow.length < _frameWindowSize) return;

    final frames = List<FrameTiming>.of(_frameWindow);
    _frameWindow.clear();
    final totals =
        frames.map((frame) => frame.totalSpan.inMicroseconds).toList()..sort();
    final p95 = totals[(totals.length * 0.95).ceil() - 1];
    final janky = frames.where((frame) {
      return frame.buildDuration > _jankThreshold ||
          frame.rasterDuration > _jankThreshold;
    }).length;
    developer.Timeline.instantSync(
      'readendar.frame_window',
      arguments: {
        'frames': frames.length,
        'p95_total_ms': p95 / Duration.microsecondsPerMillisecond,
        'janky_frames': janky,
      },
    );
  }
}
