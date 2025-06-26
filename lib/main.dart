import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT MQTT Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0F0F23),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
      ),
      home: IoTControllerPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class IoTControllerPage extends StatefulWidget {
  @override
  _IoTControllerPageState createState() => _IoTControllerPageState();
}

class _IoTControllerPageState extends State<IoTControllerPage>
    with TickerProviderStateMixin {
  MqttServerClient? client;
  bool isConnected = false;
  String connectionStatus = 'Disconnected';

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotationAnimation;

  // MQTT Configuration
  String broker = '192.168.198.188';
  int port = 1883;
  String clientId = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';
  String username = '';
  String password = '';

  // Topics
  String ledTopic = 'esp32/led';
  String led2Topic = 'esp32/led2'; // Tambahan
  String led3Topic = 'esp32/led3'; // Tambahan
  String sensorTopic = 'esp32/sensor';
  String statusTopic = 'esp32/status';

  // Device States
  bool ledState = false;
  bool led2State = false; // Tambahan
  bool led3State = false; // Tambahan
  double temperature = 0.0;
  double humidity = 0.0;
  String deviceStatus = 'Offline';
  int uptime = 0;

  // Controllers
  TextEditingController brokerController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController topicController = TextEditingController();

  @override
  void initState() {
    super.initState();
    brokerController.text = broker;
    setupMqttClient();
    _initAnimations();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2.0,
    ).animate(_rotationController);

    _slideController.forward();
  }

  void setupMqttClient() {
    client = MqttServerClient(broker, clientId);
    client!.port = port;
    client!.keepAlivePeriod = 30;
    client!.onDisconnected = onDisconnected;
    client!.onConnected = onConnected;
    client!.onSubscribed = onSubscribed;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillTopic('clients/flutter')
        .withWillMessage('Flutter client disconnected')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    if (username.isNotEmpty && password.isNotEmpty) {
      connMess.authenticateAs(username, password);
    }

    client!.connectionMessage = connMess;
  }

  Future<void> connectToMqtt() async {
    setState(() {
      connectionStatus = 'Connecting...';
    });

    broker = brokerController.text;
    username = usernameController.text;
    password = passwordController.text;

    setupMqttClient();

    try {
      await client!.connect();
    } catch (e) {
      print('Exception: $e');
      client!.disconnect();
      setState(() {
        connectionStatus = 'Connection failed: ${e.toString()}';
        isConnected = false;
      });
    }
  }

  void onConnected() {
    setState(() {
      connectionStatus = 'Connected';
      isConnected = true;
    });

    client!.subscribe(sensorTopic, MqttQos.atMostOnce);
    client!.subscribe(statusTopic, MqttQos.atMostOnce);

    client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final message = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );

      handleIncomingMessage(c[0].topic, message);
    });

    print('Connected to MQTT broker');
  }

  void onDisconnected() {
    setState(() {
      connectionStatus = 'Disconnected';
      isConnected = false;
      deviceStatus = 'Offline';
    });
    print('Disconnected from MQTT broker');
  }

  void onSubscribed(String topic) {
    print('Subscribed to topic: $topic');
  }

  void handleIncomingMessage(String topic, String message) {
    print('Received message: $message from topic: $topic');

    setState(() {
      if (topic == sensorTopic) {
        try {
          final data = json.decode(message);
          temperature = data['temperature']?.toDouble() ?? 0.0;
          humidity = data['humidity']?.toDouble() ?? 0.0;
        } catch (e) {
          print('Error parsing sensor data: $e');
        }
      } else if (topic == statusTopic) {
        try {
          final data = json.decode(message);
          deviceStatus = data['status'] ?? 'Offline';
          uptime = data['uptime']?.toInt() ?? 0;
        } catch (e) {
          print('Error parsing status data: $e');
          deviceStatus = message;
        }
      }
      // Tambahan: update state LED jika ada feedback dari device (opsional)
      else if (topic == ledTopic) {
        try {
          final data = json.decode(message);
          ledState = data['led'] ?? ledState;
        } catch (_) {}
      } else if (topic == led2Topic) {
        try {
          final data = json.decode(message);
          led2State = data['led2'] ?? led2State;
        } catch (_) {}
      } else if (topic == led3Topic) {
        try {
          final data = json.decode(message);
          led3State = data['led3'] ?? led3State;
        } catch (_) {}
      }
    });
  }

  void publishMessage(String topic, String message) {
    if (isConnected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      client!.publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
      print('Published message: $message to topic: $topic');
    }
  }

  void toggleLED([int ledNumber = 1]) {
    if (ledNumber == 1) {
      ledState = !ledState;
      final message = json.encode({'led_index': 1, 'state': ledState});
      publishMessage(ledTopic, message);
    } else if (ledNumber == 2) {
      led2State = !led2State;
      final message = json.encode({'led_index': 2, 'state': led2State});
      publishMessage(ledTopic, message);
    } else if (ledNumber == 3) {
      led3State = !led3State;
      final message = json.encode({'led_index': 3, 'state': led3State});
      publishMessage(ledTopic, message);
    }
    setState(() {});
  }

  void disconnect() {
    client!.disconnect();
  }

  @override
  void dispose() {
    client?.disconnect();
    brokerController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    topicController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Widget _buildGlassCard({required Widget child, double? height}) {
    return Container(
      height: height,
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(padding: EdgeInsets.all(20), child: child),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    Function(String)? onChanged,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        onChanged: onChanged,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Color(0xFF64FFDA)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.white30),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.white30),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Color(0xFF64FFDA), width: 2),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required String text,
    required VoidCallback? onPressed,
    required Color color,
    bool isLoading = false,
  }) {
    return Container(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 8,
          shadowColor: color.withOpacity(0.5),
        ),
        child:
            isLoading
                ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : Text(
                  text,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F0F23),
      appBar: AppBar(
        title: Text(
          'IoT MQTT Controller',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F23), Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection Section
              SlideTransition(
                position: _slideAnimation,
                child: _buildGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.wifi, color: Color(0xFF64FFDA), size: 28),
                          SizedBox(width: 10),
                          Text(
                            'MQTT Connection',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      _buildTextField(
                        controller: brokerController,
                        label: 'MQTT Broker',
                        icon: Icons.dns,
                        onChanged: (value) => broker = value,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: usernameController,
                              label: 'Username',
                              icon: Icons.person,
                              onChanged: (value) => username = value,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(
                              controller: passwordController,
                              label: 'Password',
                              icon: Icons.lock,
                              isPassword: true,
                              onChanged: (value) => password = value,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernButton(
                              text: 'Connect',
                              onPressed: isConnected ? null : connectToMqtt,
                              color: Color(0xFF4CAF50),
                              isLoading: connectionStatus == 'Connecting...',
                            ),
                          ),
                          SizedBox(width: 15),
                          Expanded(
                            child: _buildModernButton(
                              text: 'Disconnect',
                              onPressed: isConnected ? disconnect : null,
                              color: Color(0xFFE57373),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale:
                                    isConnected ? _pulseAnimation.value : 1.0,
                                child: Icon(
                                  Icons.circle,
                                  color:
                                      isConnected
                                          ? Color(0xFF4CAF50)
                                          : Color(0xFFE57373),
                                  size: 12,
                                ),
                              );
                            },
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Status: $connectionStatus',
                            style: TextStyle(
                              color:
                                  isConnected
                                      ? Color(0xFF4CAF50)
                                      : Color(0xFFE57373),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Device Status
              _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: _rotationAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle:
                                  deviceStatus.toLowerCase() == 'online'
                                      ? _rotationAnimation.value * 3.14159
                                      : 0,
                              child: Icon(
                                Icons.settings,
                                color: Color(0xFF64FFDA),
                                size: 28,
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Device Status',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale:
                                  deviceStatus.toLowerCase() == 'online'
                                      ? _pulseAnimation.value
                                      : 1.0,
                              child: Icon(
                                Icons.circle,
                                color:
                                    deviceStatus.toLowerCase() == 'online'
                                        ? Color(0xFF4CAF50)
                                        : Color(0xFFE57373),
                                size: 16,
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 12),
                        Text(
                          deviceStatus.toUpperCase(),
                          style: TextStyle(
                            color:
                                deviceStatus.toLowerCase() == 'online'
                                    ? Color(0xFF4CAF50)
                                    : Color(0xFFE57373),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        if (uptime > 0) ...[
                          Spacer(),
                          Icon(Icons.timer, size: 20, color: Color(0xFF64FFDA)),
                          SizedBox(width: 8),
                          Text(
                            'Uptime: ${_formatUptime(uptime)}',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Control Section
              _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: Color(0xFF64FFDA),
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Device Control',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    // LED 1
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: ledState ? _pulseAnimation.value : 1.0,
                                child: Icon(
                                  Icons.lightbulb,
                                  color:
                                      ledState
                                          ? Color(0xFFFFD700)
                                          : Colors.grey,
                                  size: 40,
                                ),
                              );
                            },
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: Text(
                              'LED 1: ${ledState ? "ON" : "OFF"}',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: 1.2,
                            child: Switch(
                              value: ledState,
                              onChanged:
                                  isConnected ? (value) => toggleLED(1) : null,
                              activeColor: Color(0xFF64FFDA),
                              activeTrackColor: Color(
                                0xFF64FFDA,
                              ).withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    // LED 2
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: led2State ? _pulseAnimation.value : 1.0,
                                child: Icon(
                                  Icons.lightbulb,
                                  color:
                                      led2State
                                          ? Color(0xFF00E676)
                                          : Colors.grey,
                                  size: 40,
                                ),
                              );
                            },
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: Text(
                              'LED 2: ${led2State ? "ON" : "OFF"}',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: 1.2,
                            child: Switch(
                              value: led2State,
                              onChanged:
                                  isConnected ? (value) => toggleLED(2) : null,
                              activeColor: Color(0xFF00E676),
                              activeTrackColor: Color(
                                0xFF00E676,
                              ).withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    // LED 3
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: led3State ? _pulseAnimation.value : 1.0,
                                child: Icon(
                                  Icons.lightbulb,
                                  color:
                                      led3State
                                          ? Color(0xFF2979FF)
                                          : Colors.grey,
                                  size: 40,
                                ),
                              );
                            },
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: Text(
                              'LED 3: ${led3State ? "ON" : "OFF"}',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: 1.2,
                            child: Switch(
                              value: led3State,
                              onChanged:
                                  isConnected ? (value) => toggleLED(3) : null,
                              activeColor: Color(0xFF2979FF),
                              activeTrackColor: Color(
                                0xFF2979FF,
                              ).withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Sensor Data Section
              _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sensors, color: Color(0xFF64FFDA), size: 28),
                        SizedBox(width: 10),
                        Text(
                          'Sensor Data',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFFF6B6B).withOpacity(0.2),
                                  Color(0xFFFF6B6B).withOpacity(0.1),
                                ],
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.thermostat,
                                  size: 40,
                                  color: Color(0xFFFF6B6B),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  '${temperature.toStringAsFixed(1)}°C',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Temperature',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF64FFDA).withOpacity(0.2),
                                  Color(0xFF64FFDA).withOpacity(0.1),
                                ],
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.water_drop,
                                  size: 40,
                                  color: Color(0xFF64FFDA),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  '${humidity.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Humidity',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatUptime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }
}
