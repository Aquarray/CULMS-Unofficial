import 'dart:async';
import 'dart:convert';

/// Represents a single Server-Sent Event (SSE) frame.
class SseEvent {
  final String? id;
  final String event;
  final String data;

  const SseEvent({
    this.id,
    required this.event,
    required this.data,
  });

  @override
  String toString() => 'SseEvent(id: $id, event: $event, data: $data)';
}

/// Incrementally decodes UTF-8 byte chunks and transforms them into [SseEvent]s.
/// Handles:
/// - Arbitrary network chunk boundaries (including multi-byte UTF-8 split across chunks)
/// - Both LF (\n) and CRLF (\r\n) line terminators
/// - Event dispatch on blank lines
/// - Multi-line `data:` frames joined with newline (\n)
/// - Server comments (`: heartbeat`) ignored
/// - Unknown event lines/fields ignored
class SseParser {
  final _controller = StreamController<SseEvent>();
  late final ByteConversionSink _utf8Sink;

  final StringBuffer _lineBuffer = StringBuffer();
  final List<String> _dataLines = [];
  String? _currentEvent;
  String? _currentId;
  bool _lastWasCr = false;

  SseParser() {
    final stringSink = StringConversionSink.from(_StringChunkSink(_handleStringChunk));
    _utf8Sink = utf8.decoder.startChunkedConversion(stringSink);
  }

  Stream<SseEvent> get stream => _controller.stream;

  /// Feed a chunk of bytes from the network response stream.
  void addBytes(List<int> bytes) {
    if (_controller.isClosed) return;
    _utf8Sink.add(bytes);
  }

  /// Feed a string chunk directly (useful for tests or text streams).
  void addString(String chunk) {
    _handleStringChunk(chunk);
  }

  /// Signal stream completion.
  void close() {
    if (_controller.isClosed) return;
    try {
      _utf8Sink.close();
    } catch (_) {}

    // Flush any remaining characters in the line buffer
    if (_lineBuffer.isNotEmpty) {
      _processLine(_lineBuffer.toString());
      _lineBuffer.clear();
    }

    _dispatchCurrentEvent();
    _controller.close();
  }

  void _handleStringChunk(String chunk) {
    if (_controller.isClosed) return;

    for (int i = 0; i < chunk.length; i++) {
      final char = chunk[i];

      if (char == '\r') {
        _lastWasCr = true;
        _processLine(_lineBuffer.toString());
        _lineBuffer.clear();
      } else if (char == '\n') {
        if (_lastWasCr) {
          // CRLF sequence: \r was already processed as line terminator, skip the \n
          _lastWasCr = false;
        } else {
          // LF line terminator
          _processLine(_lineBuffer.toString());
          _lineBuffer.clear();
        }
      } else {
        _lastWasCr = false;
        _lineBuffer.write(char);
      }
    }
  }

  void _processLine(String line) {
    // Empty line triggers event dispatch
    if (line.isEmpty) {
      _dispatchCurrentEvent();
      return;
    }

    // Comment line (e.g. ": heartbeat") -> ignore
    if (line.startsWith(':')) {
      return;
    }

    if (line.startsWith('event:')) {
      var val = line.substring(6);
      if (val.startsWith(' ')) val = val.substring(1);
      _currentEvent = val.trim();
    } else if (line.startsWith('data:')) {
      var val = line.substring(5);
      if (val.startsWith(' ')) val = val.substring(1);
      _dataLines.add(val);
    } else if (line.startsWith('id:')) {
      var val = line.substring(3);
      if (val.startsWith(' ')) val = val.substring(1);
      _currentId = val.trim();
    }
    // Unknown fields (e.g. retry:) are ignored
  }

  void _dispatchCurrentEvent() {
    if (_dataLines.isNotEmpty) {
      final event = SseEvent(
        id: _currentId,
        event: _currentEvent ?? 'message',
        data: _dataLines.join('\n'),
      );
      _currentEvent = null;
      _currentId = null;
      _dataLines.clear();

      if (!_controller.isClosed) {
        _controller.add(event);
      }
    }
  }

  /// Helper to transform a raw byte stream into an [SseEvent] stream.
  static Stream<SseEvent> parseByteStream(Stream<List<int>> byteStream) {
    final parser = SseParser();
    late final StreamSubscription<List<int>> sub;

    sub = byteStream.listen(
      parser.addBytes,
      onError: (err, stack) {
        if (!parser._controller.isClosed) {
          parser._controller.addError(err, stack);
          parser.close();
        }
      },
      onDone: () {
        parser.close();
      },
      cancelOnError: true,
    );

    parser._controller.onCancel = () {
      sub.cancel();
    };

    return parser.stream;
  }
}

class _StringChunkSink implements Sink<String> {
  final void Function(String) onChunk;

  _StringChunkSink(this.onChunk);

  @override
  void add(String chunk) => onChunk(chunk);

  @override
  void close() {}
}
