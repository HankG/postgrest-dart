//Modified from package:flutter/foundation/_isolates_io.dart

import 'dart:async';
import 'dart:isolate';

import 'isolates.dart' as isolates;

/// The dart:io implementation of [isolate.compute].
Future<R> compute<Q, R>(
    isolates.ComputeCallback<Q, R> callback, Q message) async {
  final RawReceivePort port = RawReceivePort();

  void cleanup() {
    port.close();
  }

  final Completer<dynamic> completer = Completer<dynamic>();
  port.handler = (dynamic msg) {
    cleanup();
    completer.complete(msg);
  };

  try {
    await Isolate.spawn<_IsolateConfiguration<Q, R>>(
      _spawn,
      _IsolateConfiguration<Q, R>(
        callback,
        message,
        port.sendPort,
      ),
      errorsAreFatal: true,
      onExit: port.sendPort,
      onError: port.sendPort,
    );
  } on Object {
    cleanup();
    rethrow;
  }

  final dynamic response = await completer.future;
  if (response == null) {
    throw RemoteError('Isolate exited without result or error.', '');
  }

  assert(response is List<dynamic>);
  response as List<dynamic>;

  final int type = response.length;
  assert(1 <= type && type <= 3);

  switch (type) {
    // success; see _buildSuccessResponse
    case 1:
      return response[0] as R;

    // native error; see Isolate.addErrorListener
    case 2:
      await Future<Never>.error(RemoteError(
        response[0] as String,
        response[1] as String,
      ));

    // caught error; see _buildErrorResponse
    case 3:
    default:
      assert(type == 3 && response[2] == null);

      await Future<Never>.error(
        response[0] as Object,
        response[1] as StackTrace,
      );
  }
}

class _IsolateConfiguration<Q, R> {
  const _IsolateConfiguration(
    this.callback,
    this.message,
    this.resultPort,
  );
  final isolates.ComputeCallback<Q, R> callback;
  final Q message;
  final SendPort resultPort;

  FutureOr<R> apply() {
    return callback(message);
  }
}

/// The spawn point MUST guarantee only one result event is sent through the
/// [SendPort.send] be it directly or indirectly i.e. [Isolate.exit].
///
/// In case an [Error] or [Exception] are thrown AFTER the data
/// is sent, they will NOT be handled or reported by the main [Isolate] because
/// it stops listening after the first event is received.
///
/// Also use the helpers [_buildSuccessResponse] and [_buildErrorResponse] to
/// build the response
Future<void> _spawn<Q, R>(_IsolateConfiguration<Q, R> configuration) async {
  late final List<dynamic> computationResult;

  try {
    computationResult = _buildSuccessResponse(await configuration.apply());
  } catch (e, s) {
    computationResult = _buildErrorResponse(e, s);
  }

  Isolate.exit(configuration.resultPort, computationResult);
}

/// Wrap in [List] to ensure our expectations in the main [Isolate] are met.
///
/// We need to wrap a success result in a [List] because the user provided type
/// [R] could also be a [List]. Meaning, a check `result is R` could return true
/// for what was an error event.
List<R> _buildSuccessResponse<R>(R result) {
  return List<R>.filled(1, result);
}

/// Wrap in [List] to ensure our expectations in the main isolate are met.
///
/// We wrap a caught error in a 3 element [List]. Where the last element is
/// always null. We do this so we have a way to know if an error was one we
/// caught or one thrown by the library code.
List<dynamic> _buildErrorResponse(Object error, StackTrace stack) {
  return List<dynamic>.filled(3, null)
    ..[0] = error
    ..[1] = stack;
}
