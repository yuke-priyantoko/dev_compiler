/// Command line tool to run the checker on a Dart program.
library ddc.devc;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart' show Level, Logger, LogRecord;
import 'package:path/path.dart' as path;

import 'package:ddc/src/checker/checker.dart';
import 'package:ddc/src/checker/resolver.dart' show TypeResolver;
import 'package:ddc/src/codegen/dart_codegen.dart';
import 'package:ddc/src/codegen/js_codegen.dart';
import 'package:ddc/src/report.dart';

/// Sets up the type checker logger to print a span that highlights error
/// messages.
StreamSubscription setupLogger(Level level, printFn) {
  Logger.root.level = level;
  return Logger.root.onRecord.listen((LogRecord rec) {
    printFn('${rec.level.name.toLowerCase()}: ${rec.message}');
  });
}

/// Compiles [inputFile] writing output as specified by the arguments.
/// [dumpInfoFile] will only be used if [dumpInfo] is true.
Future<bool> compile(String inputFile, TypeResolver resolver,
    {bool checkSdk: false, bool formatOutput: false, bool outputDart: false,
    String outputDir, bool dumpInfo: false, String dumpInfoFile,
    String dumpSrcTo: null, bool forceCompile: false, bool useColors: true,
    bool covariantGenerics: true, bool relaxedCasts: true}) {

  // Run checker
  var reporter = dumpInfo ? new SummaryReporter() : new LogReporter(useColors);
  var uri = new Uri.file(path.absolute(inputFile));
  var results = checkProgram(uri, resolver, reporter,
      checkSdk: checkSdk,
      useColors: useColors,
      covariantGenerics: covariantGenerics,
      relaxedCasts: relaxedCasts);

  // TODO(sigmund): return right after?
  if (dumpInfo) {
    print(summaryToString(reporter.result));
    if (dumpInfoFile != null) {
      new File(dumpInfoFile)
          .writeAsStringSync(JSON.encode(reporter.result.toJsonMap()));
    }
  }

  if (results.failure && !forceCompile) return new Future.value(false);

  // Dump the source if requested
  if (dumpSrcTo != null) {
    var cg = new EmptyDartGenerator(
        dumpSrcTo, uri, results.libraries, results.rules, formatOutput);
    cg.generate().then((_) => true);
  }

  // Generate code.
  if (outputDir != null) {
    var cg = outputDart
        ? new DartGenerator(
            outputDir, uri, results.libraries, results.rules, formatOutput)
        : new JSGenerator(outputDir, uri, results.libraries, results.rules);
    return cg.generate().then((_) => true);
  }

  return new Future.value(true);
}

final _log = new Logger('ddc');
