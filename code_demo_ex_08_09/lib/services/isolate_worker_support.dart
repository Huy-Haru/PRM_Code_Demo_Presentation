import 'dart:async';
import 'dart:isolate';

import '../models/demo_models.dart';

// Phần hỗ trợ vòng đời worker. Code chính để thuyết trình ở lib/demo/.
typedef WorkerAction = Future<AnalysisResult?> Function(
  AnalysisRequest request,
  SendPort mainPort,
  CancellationSignal cancellation,
);

class CancellationSignal {
  bool isCancelled = false;
}

class WorkerJob {
  const WorkerJob(this.request, this.replyTo, this.action);
  final AnalysisRequest request;
  final SendPort replyTo;
  final WorkerAction action;
}

class _Ready {
  const _Ready(this.commands);
  final SendPort commands;
}

class _Failure {
  const _Failure(this.error, this.stack);
  final String error;
  final String stack;
}

class _Exited {
  const _Exited();
}

void runWorkerJob(WorkerJob job) async {
  final commands = ReceivePort();
  final cancellation = CancellationSignal();
  final subscription = commands.listen((message) {
    if (message == 'cancel') cancellation.isCancelled = true;
  });
  job.replyTo.send(_Ready(commands.sendPort));
  try {
    final result = await job.action(job.request, job.replyTo, cancellation);
    if (result != null) job.replyTo.send(AnalysisCompleted(result));
  } catch (error, stack) {
    job.replyTo.send(_Failure(error.toString(), stack.toString()));
  } finally {
    await subscription.cancel();
    commands.close();
  }
}

Stream<AnalysisEvent> workerMessages(
  Future<Isolate> Function(SendPort replyTo, SendPort exitTo) spawn,
) async* {
  final inbox = ReceivePort();
  final exits = ReceivePort();
  final exited = Completer<void>();
  final exitSubscription = exits.listen((_) {
    if (!exited.isCompleted) exited.complete();
    inbox.sendPort.send(const _Exited());
  });
  Isolate? worker;
  SendPort? commands;
  try {
    worker = await spawn(inbox.sendPort, exits.sendPort);
    await for (final message in inbox) {
      if (message is _Ready) {
        commands = message.commands;
      } else if (message is AnalysisCompleted) {
        yield message;
        return;
      } else if (message is AnalysisProgress) {
        yield message;
      } else if (message is _Failure) {
        Error.throwWithStackTrace(
          StateError(message.error),
          StackTrace.fromString(message.stack),
        );
      } else if (message is List && message.length == 2) {
        Error.throwWithStackTrace(
          StateError(message[0].toString()),
          StackTrace.fromString(message[1].toString()),
        );
      } else if (message is _Exited) {
        throw StateError('Worker thoát trước khi gửi kết quả.');
      }
    }
  } finally {
    if (worker != null && !exited.isCompleted) {
      if (commands == null) {
        worker.kill(priority: Isolate.immediate);
      } else {
        commands.send('cancel');
      }
      try {
        await exited.future.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        worker.kill(priority: Isolate.immediate);
        await exited.future.timeout(const Duration(seconds: 2));
      }
    }
    inbox.close();
    await exitSubscription.cancel();
    exits.close();
  }
}
