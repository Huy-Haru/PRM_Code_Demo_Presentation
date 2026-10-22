class DemoFiles {
  const DemoFiles({
    required this.directory,
    required this.jsonPath,
    required this.ndjsonPath,
    required this.emptyPath,
    required this.recordCount,
    required this.jsonBytes,
    required this.ndjsonBytes,
  });

  final String directory;
  final String jsonPath;
  final String ndjsonPath;
  final String emptyPath;
  final int recordCount;
  final int jsonBytes;
  final int ndjsonBytes;

  String get missingPath => '$directory/missing.json';
  String get computeOutput => '$directory/summary_compute.json';
  String get isolateOutput => '$directory/summary_isolate.json';
}

// Chỉ truyền path và dữ liệu thuần, không truyền Widget/BuildContext/file handle.
class AnalysisRequest {
  const AnalysisRequest({required this.inputPath, required this.outputPath});
  final String inputPath;
  final String outputPath;
}

class AnalysisResult {
  const AnalysisResult({
    required this.records,
    required this.averageScore,
    required this.completedActivities,
    required this.sampleNames,
    required this.elapsedMicroseconds,
    required this.outputPath,
  });

  final int records;
  final double averageScore;
  final int completedActivities;
  final List<String> sampleNames;
  final int elapsedMicroseconds;
  final String outputPath;

  Map<String, Object> toJson() => {
    'records': records,
    'averageScore': averageScore,
    'completedActivities': completedActivities,
    'sampleNames': sampleNames,
  };
}

sealed class AnalysisEvent {
  const AnalysisEvent();
}

class AnalysisProgress extends AnalysisEvent {
  const AnalysisProgress(this.bytesRead, this.totalBytes, this.records);
  final int bytesRead;
  final int totalBytes;
  final int records;
  double get fraction => totalBytes == 0
      ? 1.0
      : (bytesRead / totalBytes).clamp(0.0, 1.0).toDouble();
}

class AnalysisCompleted extends AnalysisEvent {
  const AnalysisCompleted(this.result);
  final AnalysisResult result;
}

class ReadProgress {
  const ReadProgress({
    required this.bytesRead,
    required this.totalBytes,
    required this.elapsedMicroseconds,
    this.isComplete = false,
  });

  final int bytesRead;
  final int totalBytes;
  final int elapsedMicroseconds;
  final bool isComplete;
  double get fraction => totalBytes == 0
      ? (isComplete ? 1.0 : 0.0)
      : (bytesRead / totalBytes).clamp(0.0, 1.0).toDouble();
}
