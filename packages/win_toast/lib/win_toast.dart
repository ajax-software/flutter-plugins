import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:win_toast/src/templates.dart';
import 'package:win_toast/src/toast_type.dart';

export 'src/toast_type.dart';
export 'src/templates.dart';


enum DismissReason {
  userCanceld,
  applicationHidden,
  timeout,
}

class Event {
  final int _id;

  Event(this._id);
}

class ActivatedEvent extends Event {
  ActivatedEvent(this.actionIndex, int id) : super(id);

  final int? actionIndex;

  @override
  String toString() {
    return 'ActivatedEvent{actionIndex: $actionIndex}';
  }
}

class DissmissedEvent extends Event {
  DissmissedEvent(int id, this.dismissReason) : super(id);

  final DismissReason dismissReason;

  @override
  String toString() {
    return 'DissmissedEvent{dismissReason: $dismissReason}';
  }
}

class FailedEvent extends Event {
  FailedEvent(int id) : super(id);
}

class _EndEvent extends Event {
  _EndEvent(int id) : super(id);
}

class WinToast {
  WinToast._private();

  static const MethodChannel _channel = MethodChannel('win_toast');

  static WinToast? _winToast;

  static WinToast instance() {
    if (_winToast == null) {
      _winToast = WinToast._private();
      _channel.setMethodCallHandler((call) async {
        try {
          return await _winToast!._handleMethodcall(call);
        } catch (e, s) {
          debugPrint('error: $e $s');
        }
      });
    }
    return _winToast!;
  }

  bool _supportToast = false;

  final _activatedStream = StreamController<Event>.broadcast();

  Future<dynamic> _handleMethodcall(MethodCall call) async {
    if (call.method != 'OnNotificationStatusChanged') {
      return;
    }
    final String action = call.arguments['action'];
    final int id = call.arguments['id'];
    assert(id != -1);

    switch (action) {
      case 'activated':
        _activatedStream.add(
          ActivatedEvent(call.arguments['actionIndex'], id),
        );
        break;
      case 'dismissed':
        final int reason = call.arguments['reason'];
        assert(const [0, 1, 2].contains(reason));
        _activatedStream.add(DissmissedEvent(id, DismissReason.values[reason]));
        break;
      case 'failed':
        _activatedStream.add(FailedEvent(id));
        break;
      case 'end':
        _activatedStream.add(_EndEvent(id));
        break;
      default:
        break;
    }
  }

  /// Initialize the WinToast.
  ///
  /// [aumId], [displayName], [iconPath] is config for normal exe application,
  /// wouldn't have any effect if the application is a UWP application.
  /// [clsid] is config for UWP application, wouldn't have effect for normal exe application.
  ///
  /// [aumId] application user model id.
  /// [displayName] toast application display name.
  /// [clsid] notification activator clsid, must be a valid guid string and the
  ///           same as the one in the manifest file. it's format is like this:
  ///           '00000000-0000-0000-0000-000000000000'
  Future<bool> initialize({
    required String aumId,
    required String displayName,
    required String iconPath,
    required String clsid,
  }) async {
    try {
      await _channel.invokeMethod("initialize", {
        'aumid': aumId,
        'display_name': displayName,
        'icon_path': iconPath,
        'clsid': clsid,
      });
      _supportToast = true;
    } catch (e) {
      debugPrint('initialize: ${e.toString()}');
      _supportToast = false;
    }
    return _supportToast;
  }

  /// return notification id. -1 meaning failed to show.
  Future<void> showToast({
    required Toast toast,
    String? tag,
    String? group,
  }) {
    return showCustomToast(
      xml: toast.toXmlString(),
      tag: tag,
      group: group,
    );
  }

    /// Show a toast notification.
  /// [xml] is the raw XML content of win toast. schema can be found here:
  ///       https://learn.microsoft.com/en-us/uwp/schemas/tiles/toastschema/schema-root
  ///
  /// [tag] notification tag, you can use this to remove the notification.
  ///
  /// [group] notification group, you can use this to remove the notification.
  ///         Maybe this string needs to be max 16 characters to work on Windows
  ///         10 prior to applying Creators Update (build 15063).
  ///         see here: https://chromium.googlesource.com/chromium/src/+/1f65ad79494a05653e7478202e221ec229d9ed01/chrome/browser/notifications/notification_platform_bridge_win.cc#56
  Future<void> showCustomToast({
    required String xml,
    String? tag,
    String? group,
  }) async {
    if (!_supportToast) {
      return;
    }
    await _channel.invokeMethod<int>("showCustomToast", {
      'xml': xml,
      'tag': tag ?? '',
      'group': group ?? '',
    });
  }

  Future<void> clear() {
    return _channel.invokeMethod('clear');
  }

  Future<void> _dismiss(int id) {
    return _channel.invokeMethod('hide', id);
  }

  Future<void> bringWindowToFront() {
    return _channel.invokeMethod('bringWindowToFront');
  }
}
