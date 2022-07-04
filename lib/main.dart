// ----------------------------------------------------------------------------
// -                        Prestige Medical Ltd.                             -
// -                       East House, Duttons Way                            -
// -                            Blackburn,                                    -
// -                           Lancashire,                                    -
// -                               UK.                                        -
// -                             BB1 2QR                                      -
// -                                                                          -
// -       (c) Copyright 2016, Prestige Medical Ltd., Blackburn, UK.          -
// -                                                                          -
// ----------------------------------------------------------------------------
// - Packet Communication Interface
// - Main Header
// ----------------------------------------------------------------------------
// -
// - Author:    Joshua Longhurst MSc BEng
// - Created:   Oct 2021
// -
// ----------------------------------------------------------------------------
// For performing some operations asynchronously
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:io';

// For using PlatformException
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prestige Bluetooth App',
      theme: ThemeData(
        primarySwatch: Colors.grey,
      ),
      home: BluetoothApp(),
    );
  }
}

class BluetoothApp extends StatefulWidget {
  @override
  _BluetoothAppState createState() => _BluetoothAppState();
}

class _BluetoothAppState extends State<BluetoothApp> {
  // Initializing the Bluetooth connection state to be unknown
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  // Initializing a global key, as it would help us in showing a SnackBar later
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  // Get the instance of the Bluetooth
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  // Track the Bluetooth connection with the remote device
  BluetoothConnection connection;

  List<int> _buffer = List<int>.empty(growable: true);

  Uint8 temp;
  int _deviceState;
  String _row1;
  String _row2;
  String _row3;
  String _row4;

  bool isDisconnecting = false;

  Map<String, Color> colors = {
    'onBorderColor': Colors.green,
    'offBorderColor': Colors.red,
    'neutralBorderColor': Colors.transparent,
    'onTextColor': Colors.green[700],
    'offTextColor': Colors.red[700],
    'neutralTextColor': Colors.blue,
  };

  // To track whether the device is still connected to Bluetooth
  bool get isConnected => connection != null && connection.isConnected;

  // Define some variables, which will be required later
  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice _device;
  bool _connected = false;
  bool _isButtonUnavailable = false;

  @override
  void initState() {
    super.initState();

    // Get current state
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    _deviceState = 0; // neutral

    // If the bluetooth of the device is not enabled,
    // then request permission to turn on bluetooth
    // as the app starts up
    enableBluetooth();

    // Listen for further state changes
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;
        if (_bluetoothState == BluetoothState.STATE_OFF) {
          _isButtonUnavailable = true;
        }
        getPairedDevices();
      });
    });
  }

  @override
  void dispose() {
    // Avoid memory leak and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }

    super.dispose();
  }

  // Request Bluetooth permission from the user
  Future<void> enableBluetooth() async {
    // Retrieving the current Bluetooth state
    _bluetoothState = await FlutterBluetoothSerial.instance.state;

    // If the bluetooth is off, then turn it on first
    // and then retrieve the devices that are paired.
    if (_bluetoothState == BluetoothState.STATE_OFF) {
      await FlutterBluetoothSerial.instance.requestEnable();
      await getPairedDevices();
      return true;
    } else {
      await getPairedDevices();
    }
    return false;
  }

  // For retrieving and storing the paired devices
  // in a list.
  Future<void> getPairedDevices() async {
    List<BluetoothDevice> devices = [];

    // To get the list of paired devices
    try {
      devices = await _bluetooth.getBondedDevices();
    } on PlatformException {
      print("Error");
    }

    // It is an error to call [setState] unless [mounted] is true.
    if (!mounted) {
      return;
    }

    // Store the [devices] list in the [_devicesList] for accessing
    // the list outside this class
    setState(() {
      _devicesList = devices;
    });
  }

  // Now, its time to build the UI
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Image.asset('images/PrestigeMedicalLogo-WHITE.png',
              width: 200, height: 100),
          backgroundColor: Colors.grey,
          actions: <Widget>[
            FlatButton.icon(
              icon: Icon(
                Icons.refresh,
                color: Colors.white,
              ),
              label: Text(
                "Refresh",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              splashColor: Colors.grey,
              onPressed: () async {
                // So, that when new devices are paired
                // while the app is running, user can refresh
                // the paired devices list.
                await getPairedDevices().then((_) {
                  show('Device list refreshed');
                });
              },
            ),
          ],
        ),
        body: Container(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Visibility(
                visible: _isButtonUnavailable &&
                    _bluetoothState == BluetoothState.STATE_ON,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.yellow,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
              Padding(
                //enable bluetooth switch
                padding: const EdgeInsets.only(
                    top: 8, bottom: 6, left: 10, right: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Enable Bluetooth',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Switch(
                      value: _bluetoothState.isEnabled,
                      onChanged: (bool value) {
                        future() async {
                          if (value) {
                            await FlutterBluetoothSerial.instance
                                .requestEnable();
                          } else {
                            await FlutterBluetoothSerial.instance
                                .requestDisable();
                          }

                          await getPairedDevices();
                          _isButtonUnavailable = false;

                          if (_connected) {
                            _disconnect();
                          }
                        }

                        future().then((_) {
                          setState(() {});
                        });
                      },
                    )
                  ],
                ),
              ),
              Stack(
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      Padding(
                        // Paired devices title
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          "PAIRED DEVICES",
                          style: TextStyle(fontSize: 24, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        // drop-down menu for devices
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'Device:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            DropdownButton(
                              items: _getDeviceItems(),
                              onChanged: (value) =>
                                  setState(() => _device = value),
                              value: _devicesList.isNotEmpty ? _device : null,
                            ),
                            ElevatedButton(
                              onPressed: _isButtonUnavailable
                                  ? null
                                  : _connected
                                      ? _disconnect
                                      : _connect,
                              child:
                                  Text(_connected ? 'Disconnect' : 'Connect'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        ////UI to display LCD data
                        padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          elevation: _deviceState == 0 ? 4 : 0,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _connected
                                  ? <Widget>[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '_row1',
                                            style: TextStyle(
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '_row2',
                                            style: TextStyle(
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '_row3',
                                            style: TextStyle(
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '_row4',
                                            style: TextStyle(
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ]
                                  : <Widget>[
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'disconnected',
                                            style: TextStyle(
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        //Top row of advance buttons
                        padding: const EdgeInsets.only(
                            top: 8.0, left: 20.0, right: 20.0),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            side: new BorderSide(
                              color: _deviceState == 0
                                  ? colors['neutralBorderColor']
                                  : _deviceState == 1
                                      ? colors['onBorderColor']
                                      : colors['offBorderColor'],
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          elevation: _deviceState == 0 ? 4 : 0,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                TextButton(
                                  //POWER BUTTON
                                  onPressed: _connected
                                      ? _sendPowerMessageToBluetooth
                                      : null,
                                  child: const Icon(
                                      Icons.power_settings_new_rounded,
                                      size: 35),
                                ),
                                TextButton(
                                  //VAC BUTTON
                                  onPressed: _connected
                                      ? _sendVacMessageToBluetooth
                                      : null,
                                  child: const Text("B",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 35)),
                                ),
                                TextButton(
                                  //DRYING BUTTON
                                  onPressed: _connected
                                      ? _sendDryingMessageToBluetooth
                                      : null,
                                  child: Icon(Icons.whatshot, size: 35),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        //lower row of advance buttons
                        padding: const EdgeInsets.only(left: 20.0, right: 20.0),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            side: new BorderSide(
                              color: _deviceState == 0
                                  ? colors['neutralBorderColor']
                                  : _deviceState == 1
                                      ? colors['onBorderColor']
                                      : colors['offBorderColor'],
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          elevation: _deviceState == 0 ? 4 : 0,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                TextButton(
                                  //NON VAC BUTTON
                                  onPressed: _connected
                                      ? _sendNonvacMessageToBluetooth
                                      : null,
                                  child: Text("N",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 35)),
                                ),
                                TextButton(
                                  //START BUTTON
                                  onPressed: _connected
                                      ? _sendStartMessageToBluetooth
                                      : null,
                                  child: const Icon(Icons.play_circle_outline,
                                      size: 35),
                                ),
                                TextButton(
                                  //DOOR BUTTON
                                  onPressed: _connected
                                      ? _sendDoorMessageToBluetooth
                                      : null,
                                  child: const Icon(Icons.sensor_door_outlined,
                                      size: 35),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    color: Colors.grey,
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        //Text(
                        //  "NOTE: If you cannot find the device in the list, please pair the device by going to the bluetooth settings",
                        //  style: TextStyle(
                        //    fontSize: 15,
                        //    fontWeight: FontWeight.bold,
                        //    color: Colors.red,
                        //  ),
                        //),
                        //SizedBox(height: 15),
                        ElevatedButton(
                          child: Text("Bluetooth Settings"),
                          onPressed: () {
                            FlutterBluetoothSerial.instance.openSettings();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Create the List of devices to be shown in Dropdown Menu
  List<DropdownMenuItem<BluetoothDevice>> _getDeviceItems() {
    List<DropdownMenuItem<BluetoothDevice>> items = [];
    if (_devicesList.isEmpty) {
      items.add(DropdownMenuItem(
        child: Text('NONE'),
      ));
    } else {
      _devicesList.forEach((device) {
        items.add(DropdownMenuItem(
          child: Text(device.name),
          value: device,
        ));
      });
    }
    return items;
  }

  // Method to connect to bluetooth
  void _connect() async {
    setState(() {
      _isButtonUnavailable = true;
    });
    if (_device == null) {
      show('No device selected');
    } else {
      if (!isConnected) {
        await BluetoothConnection.toAddress(_device.address)
            .then((_connection) {
          print('Connected to the device');
          connection = _connection;
          setState(() {
            _connected = true;
          });

          connection.input.listen(_onDataReceived).onDone(() {
            if (isDisconnecting) {
              print('Disconnecting locally!');
            } else {
              print('Disconnected remotely!');
            }
            if (this.mounted) {
              setState(() {});
            }
          });
        }).catchError((error) {
          print('Cannot connect, exception occurred');
          print(error);
        });
        show('Device connected');

        setState(() => _isButtonUnavailable = false);
      }
    }
  }

  void _onDataReceived(Uint8List value) {
    // First sort the values in the list to interpret correctly the bytes
    print(value);
    if (value[0] == 42) {
      if (value.length == 99) {
        int checksum = 0;
        for (int index = 4; index < 91; index++)
          checksum = value[index] ^ checksum;
        //print(checksum);
        //print(value[94]);
        var lcdData = String.fromCharCodes(value);
        //print(lcdData);
        _row1 = lcdData.substring(4, 24);
        _row2 = lcdData.substring(24, 44);
        _row3 = lcdData.substring(44, 64);
        _row4 = lcdData.substring(64, 84);
        print(_row1);
        print(_row2);
        print(_row3);
        print(_row4);
      }
    }

    //int checksum = 0;
    //for (int index = 4; index < 91; index++) checksum = fred[index] ^ checksum;
    //print(checksum);
    //print(fred[91]);

    //connection.output.add(data); // Sending data

    //if (ascii.decode(data).contains('*')) {
    // int index = _buffer.indexOf('t'.codeUnitAt(0)); // Closing connection
    // if (index >= 0 && _buffer.length - index >= 7) {}
    //print(data);
    //var lcdData = String.fromCharCodes(buffer);
    //print(lcdData);
    //_row1 = lcdData.substring(4, 24);
    //_row2 = lcdData.substring(24, 44);
    //_row3 = lcdData.substring(44, 64);
    //_row4 = lcdData.substring(64, 84);
    //print(String.fromCharCodes(buffer));
    //}
  }

  // Method to disconnect bluetooth
  void _disconnect() async {
    setState(() {
      _isButtonUnavailable = true;
      _deviceState = 0; // device state controls state of page
    });

    await connection.close();
    show('Device disconnected');
    if (!connection.isConnected) {
      setState(() {
        _connected = false;
        _isButtonUnavailable = false;
        _deviceState = 0; // device on (adds green border on row padding)
      });
    }
  }

  // Method to send message,
  // for activating power switch
  void _sendPowerMessageToBluetooth() async {
    connection.output.add(utf8.encode("P" + "\r\n"));
    await connection.output.allSent;
    show('POWER');
    setState(() {
      _deviceState = 1; // device on (adds green border on row padding)
    });
  }

  // Method to send message,
  // for activating vac switch
  void _sendVacMessageToBluetooth() async {
    connection.output.add(utf8.encode("B" + "\r\n"));
    await connection.output.allSent;
    show('VAC');
    setState(() {
      _deviceState = 1; // device on
    });
  }

  // Method to send message,
  // for activating drying switch
  void _sendDryingMessageToBluetooth() async {
    connection.output.add(utf8.encode("D" + "\r\n"));
    await connection.output.allSent;
    show('DRYING');
    setState(() {
      _deviceState = 1; // device off
    });
  }

  // Method to send message,
  // for activating non vac switch
  void _sendNonvacMessageToBluetooth() async {
    connection.output.add(utf8.encode("N" + "\r\n"));
    await connection.output.allSent;
    show('NON VAC');
    setState(() {
      _deviceState = 1; // device off
    });
  }

  // Method to send message,
  // for activating start switch
  void _sendStartMessageToBluetooth() async {
    connection.output.add(utf8.encode("S" + "\r\n"));
    await connection.output.allSent;
    show('START');
    setState(() {
      _deviceState = 1; // device off
    });
  }

  // Method to send message,
  // for activating door switch
  void _sendDoorMessageToBluetooth() async {
    connection.output.add(utf8.encode("a" + "\r\n"));
    await connection.output.allSent;
    show('DOOR');
    setState(() {
      _deviceState = 1; // device off
    });
  }

  // Method for reading LCD data
  //Future LCDdata(
  //  String message, {
  //  Duration duration: const Duration(milliseconds: 800),
  //}) async {
  //  await new Future.delayed(new Duration(milliseconds: 100));
  //}

  // Method to show a Snackbar,
  // taking message as the text
  Future show(
    String message, {
    Duration duration: const Duration(milliseconds: 800),
  }) async {
    await new Future.delayed(new Duration(milliseconds: 100));
    _scaffoldKey.currentState.showSnackBar(
      new SnackBar(
        content: new Text(
          message,
        ),
        duration: duration,
      ),
    );
  }
}
