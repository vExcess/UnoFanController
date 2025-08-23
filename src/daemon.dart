import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:libserialport/libserialport.dart' as libserialport;
import 'package:serial_port_win32/src/serial_port.dart' as winserialport;

String? portPath;

libserialport.SerialPort? lib_port = null;
winserialport.SerialPort? win_port = null;
bool connected = false;
bool nextValueIsSpeed = false;

double cpuTemp = 0;
double fanPWM = 0.3;
double fanRPM = 0;

void writeBytes(List<int> arr) {
    final bytes = Uint8List.fromList(arr);
    if (Platform.isLinux) {
        lib_port!.write(bytes);
    } else if (Platform.isWindows) {
        win_port!.writeBytesFromUint8List(bytes);
    }
}

double lerp(double a, double b, double amt) {
    return (b - a) * amt + a;
}

List<int> serialQueue = [];

final PING = 0;
final PONG = 1;
final RPM = 2;

bool useCurve = true;
List<List<double>> fanCurve = [
    [0, 0.3], 
    [20, 0.3], 
    [40, 0.3], 
    [60, 0.4], 
    [70, 0.5], 
    [80, 0.8],
    [90, 0.9],
    [100, 1.0],
];
double constantSetting = 0.3;

String configString() {
    return "${portPath}\n${useCurve}\n${fanCurve.map((a) => a[1]).join(",")}\n${constantSetting}";
}

File getConfigFile() {
    if (Platform.isLinux) {
        return File("${Platform.environment['HOME']}/.UnoFanController/config.txt");
    } else if (Platform.isWindows) {
        print("${Platform.environment['APPDATA']}\\UnoFanController\\config.txt");
        return File("${Platform.environment['APPDATA']}\\UnoFanController\\config.txt");
    }
    throw "unsupported OS";
}

void saveConfig() {
    var file = getConfigFile();

    if (!file.existsSync()) {
        file.createSync(recursive: true);
    }
    file.writeAsStringSync(configString());
}

void loadConfig() {
    var file = getConfigFile();

    if (file.existsSync()) {
        final lines = file.readAsLinesSync();

        if (lines.length == 4) {
            portPath = lines[0];

            useCurve = lines[1] == "true";
            
            final curveVals = lines[2].split(",");
            for (var i = 0; i < curveVals.length; i++) {
                fanCurve[i][1] = double.parse(curveVals[i]);
            }

            constantSetting = double.parse(lines[3]);
        }
    } else {
        // defaults
        if (Platform.isLinux) {
            portPath = "/dev/ttyACM0";
        } else if (Platform.isWindows) {
            portPath = "COM3";
        }
    }
}

void cleanup() {
    if (lib_port != null) {
        try {
            lib_port!.close();
        } catch (e) {}
        lib_port!.dispose();
        lib_port = null;
    }
    if (win_port != null) {
        try {
            win_port!.close();
        } catch (e) {}
        win_port = null;
    }
    connected = false;
}

var timeout = 0;

void start() {
    if (Platform.isLinux) {
        if (!libserialport.SerialPort.availablePorts.contains(portPath)) {
            print("Unable to locate Arduino port.");
            print("Available Ports:");
            print(libserialport.SerialPort.availablePorts);
            return;
        }
    } else if (Platform.isWindows) {
        if (!winserialport.SerialPort.getAvailablePorts().contains(portPath)) {
            print("Unable to locate Arduino port.");
            print("Available Ports:");
            print(winserialport.SerialPort.getPortsWithFullMessages());
            return;
        }
    }
    
    try {
        if (Platform.isLinux) {
            lib_port = libserialport.SerialPort(portPath!);
            if (!lib_port!.openReadWrite()) {
                print(libserialport.SerialPort.lastError);
                print("Failed to connect. Retrying in 10 seconds.");
                timeout = 10;
                cleanup();
                return;
            }

            final reader = libserialport.SerialPortReader(lib_port!);
            reader.stream.listen(
                (data) {
                    serialQueue.addAll(data);

                    while (serialQueue.isNotEmpty) {
                        final byte = serialQueue[0];

                        if (byte == PONG) {
                            if (!connected) {
                                print("Controller Connected!");
                                connected = true;
                            }
                            print("duplicate pong");
                        } else if (byte == RPM) {
                            nextValueIsSpeed = true;
                        } else {
                            if (nextValueIsSpeed) {
                                fanRPM = byte * 12;
                                nextValueIsSpeed = false;
                            } else {
                                print("RECIEVED: $byte");
                            }
                        }
                        
                        serialQueue.removeAt(0);
                    }
                },
                onError: (e) {
                    print("Arduino probably disconnected");
                    cleanup();
                }
            );
        } else if (Platform.isWindows) {
            win_port = winserialport.SerialPort(portPath!, openNow: true, ByteSize: 8, BaudRate: 9600);
            if (!win_port!.isOpened) {
                print("Failed to connect. Retrying in 10 seconds.");
                timeout = 10;
                cleanup();
                return;
            }

            void winStream() async {
                while (win_port!.isOpened) {
                    try {
                        final data = await win_port!.readBytes(1, timeout: Duration(milliseconds: 16));
                        if (data.length > 0) {
                            serialQueue.addAll(data);

                            while (serialQueue.isNotEmpty) {
                                final byte = serialQueue[0];

                                if (byte == PONG) {
                                    if (!connected) {
                                        print("Controller Connected!");
                                        connected = true;
                                    }
                                    print("duplicate pong");
                                } else if (byte == RPM) {
                                    nextValueIsSpeed = true;
                                } else {
                                    if (nextValueIsSpeed) {
                                        fanRPM = byte * 12;
                                        nextValueIsSpeed = false;
                                    } else {
                                        print("RECIEVED: $byte");
                                    }
                                }
                                
                                serialQueue.removeAt(0);
                            }
                        }
                    } catch (e) {
                        print("Arduino probably disconnected");
                        cleanup();
                    }
                    await Future.delayed(Duration(milliseconds: 16));
                }
            }
            winStream();
        }
    } catch (e) {
        print("ErrLoc2: $e");
        cleanup();
    }
}

void connectGUI() async {
    const String host = 'localhost';
    const int port = 49942;

    try {
        // Create the HTTP server.
        final HttpServer server = await HttpServer.bind(host, port);
        print('Server listening on http://$host:$port');

        final guiHTML = File("./src/gui.html").readAsStringSync();

        await for (HttpRequest request in server) {
            if (request.uri.path == '/') {
                request.response
                ..headers.contentType = ContentType.html
                ..statusCode = 200
                ..write(guiHTML);
            } else if (request.uri.path.startsWith("/poll")) {
                request.response
                ..headers.contentType = ContentType.text
                ..statusCode = 200
                ..write("$cpuTemp, $fanPWM, $fanRPM\n${configString()}");
            } else if (request.uri.path.startsWith("/set")) {
                var arg = request.uri.queryParameters["arg"];
                if (arg != null){
                    var vals = arg.split(",").map((s) => double.parse(s)).toList();
                    if (vals.length == 1) {
                        useCurve = false;
                        constantSetting = vals[0];
                        fanPWM = constantSetting;
                    } else {
                        useCurve = true;
                        for (var i = 0; i < vals.length; i++) {
                            fanCurve[i][1] = vals[i];
                        }
                    }

                    request.response
                    ..headers.contentType = ContentType.text
                    ..statusCode = 200
                    ..write("OK");

                    saveConfig();
                } else {
                    request.response
                    ..headers.contentType = ContentType.text
                    ..statusCode = 400
                    ..write("BAD");
                }
            }

            await request.response.close();
        }
    } catch (e) {
        print("GUIError: $e");
    }
}

void main() {
    connectGUI();

    loadConfig();

    Timer.periodic(Duration(seconds: 1), (_) {
        /*
            sudo apt-get install lm-sensors 
            sudo sensors-detect
            sudo service kmod start
        */
        // get temp
        if (Platform.isLinux) {
            final res = Process.runSync("sensors", ["-u"]);
            final resStr = res.stdout.toString().split("\n");
            for (var i = 0; i < resStr.length; i++) {
                final line = resStr[i];

                // Hopefully this handles most CPUs
                if (line.contains("k10temp") || line.contains("coretemp") || line.contains("x86_pkg_temp")) {
                    double avg = 0;
                    int count = 0;
                    while (i < resStr.length && resStr[i].trim().isNotEmpty) {
                        if (resStr[i].startsWith("  ") && resStr[i].contains("_input")) {
                            avg += double.parse(resStr[i].split(":")[1]);
                            count++;
                        }
                        i++;
                    }
                    cpuTemp = avg / count;
                }
            }
        } else if (Platform.isWindows) {

        }

        // calc pwm
        if (useCurve) {
            var i = 0;
            var left = fanCurve[i];
            while (i < fanCurve.length && fanCurve[i][0] <= cpuTemp) {
                left = fanCurve[i];
                i++;
            }

            i = fanCurve.length - 1;
            var right = fanCurve[i];
            while (i >= 0 && fanCurve[i][0] >= cpuTemp) {
                right = fanCurve[i];
                i--;
            }

            final divisor = right[0] - left[0];
            if (divisor == 0) {
                fanPWM = left[1];
            } else {
                fanPWM = lerp(left[1], right[1], (cpuTemp - left[0]) / divisor);
            }
        }
        
        // ping or send updates
        void pingAndUpdate() {
            try {
                if (!connected) {
                    print("ping");
                    writeBytes([PING]);
                } else {
                    writeBytes([(fanPWM * 255).round()]);
                }
            } catch (e) {
                print("ErrLoc1: $e");
            }
        }
        if (Platform.isLinux) {
            if (lib_port != null && lib_port!.isOpen) {
                pingAndUpdate();
            }
        } else if (Platform.isWindows) {
            if (win_port != null && win_port!.isOpened) {
                pingAndUpdate();
            }
        }

        // open port
        if (Platform.isLinux) {
            if (lib_port == null && timeout == 0) {
                start();
            } else if (timeout > 0) {
                timeout--;
            }
        } else if (Platform.isWindows) {
            if (win_port == null && timeout == 0) {
                start();
            } else if (timeout > 0) {
                timeout--;
            }
        }
    });
}
