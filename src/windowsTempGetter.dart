import "dart:io";
import 'dart:async';

void main() {
    Timer.periodic(Duration(seconds: 1), (_) async {
        var process = await Process.runSync("C:\\Users\\vexce\\Downloads\\OpenHardwareMonitorReport\\OpenHardwareMonitorReport.exe", []);
        final lines = process.stdout.toString().split("\n");
        var avgTemp = 0.0;
        var numTemps = 0;
        for (final line in lines) {
            final colonIdx = line.indexOf(":");
            if (line.contains("temperature") && colonIdx >= 0) {
                var t = line.substring(colonIdx + 1).trimLeft().replaceFirst("\t", " ");
                final spaceIdx = t.indexOf(" ");
                if (spaceIdx >= 0) {
                    t = t.substring(0, spaceIdx);
                }
                final temp = double.tryParse(t);
                if (temp != null) {
                    avgTemp += temp;
                    numTemps++;
                }
            }
        }
        avgTemp /= numTemps;
        print(avgTemp);
    });
}
