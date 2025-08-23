import "dart:io";
import 'dart:async';

void main() async {
  var process = await Process.start("powershell.exe", ["Start-Process", ".\\src\\windowstempgetter.exe", "-Verb", "runAs"]);
  process.stdout.pipe(stdout);
  process.stderr.pipe(stderr);
  Timer.periodic(Duration(seconds: 1), (_) {

  });
}
