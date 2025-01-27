import 'dart:io';
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:twilio_voice/twilio_voice.dart';
import 'package:dio/dio.dart';

import 'package:twilio_voice_example/call_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  return runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: DialScreen());
  }
}

class DialScreen extends StatefulWidget {
  @override
  _DialScreenState createState() => _DialScreenState();
}

class _DialScreenState extends State<DialScreen> with WidgetsBindingObserver {
  late TextEditingController _controller;
  late String userId;

  registerUser() {
    print("voip-service init");
    // if (TwilioVoice.instance.deviceToken != null) {
    //   print("device token changed");
    // }

    register();

    TwilioVoice.instance.setOnDeviceTokenChanged((token) {
      print("voip-device token changed");
      register();
    });
  }

  register() async {
    print("voip-registtering with token ");
    print("voip-calling voice-accessToken");

    String platform = Platform.isAndroid ? 'android' : 'ios';

    final response = await Dio()
        .get("http://192.168.2.13:3000/accessToken/testChristo/$platform");

    String? token = await FirebaseMessaging.instance.getToken();
    print("FCM token is " + token!);

    TwilioVoice.instance.setTokens(
        accessToken: response.data,
        deviceToken: Platform.isAndroid ? token : null);
  }

  var registered = false;
  waitForLogin() async {
    // final auth = FirebaseAuth.instance;
    // auth.authStateChanges().listen((user) async {
    // print("authStateChanges $user");
    // if (user == null) {
    //  print("user is anonomous");
    //  await auth.signInAnonymously();
    // } else if (!registered) {
    // registered = true;
    // this.userId = user.uid;
    // print("registering user ${user.uid}");
    registerUser();

    FirebaseMessaging.instance.requestPermission();

    if (await TwilioVoice.instance.requiresBackgroundPermissions()) {
      TwilioVoice.instance.requestBackgroundPermissions();
    }

    // FirebaseMessaging.instance.configure(
    //     onMessage: (Map<String, dynamic> message) {
    //   print("onMessage");
    //   print(message);
    //   return;
    // }, onLaunch: (Map<String, dynamic> message) {
    //   print("onLaunch");
    //   print(message);
    //   return;
    // }, onResume: (Map<String, dynamic> message) {
    //   print("onResume");
    //   print(message);
    //   return;
    // });
    // }
    // });
  }

  @override
  void initState() {
    super.initState();
    waitForLogin();

    super.initState();
    waitForCall();
    WidgetsBinding.instance!.addObserver(this);

    final partnerId = "testChristo";
    TwilioVoice.instance.registerClient(partnerId, "Christo");
    _controller = TextEditingController();
  }

  checkActiveCall() async {
    final isOnCall = await TwilioVoice.instance.call.isOnCall();
    print("checkActiveCall $isOnCall");
    if (isOnCall &&
        !hasPushedToCall &&
        TwilioVoice.instance.call.activeCall!.callDirection ==
            CallDirection.incoming) {
      print("user is on call");
      pushToCallScreen();
      hasPushedToCall = true;
    }
  }

  var hasPushedToCall = false;

  void waitForCall() {
    checkActiveCall();
    TwilioVoice.instance.callEventsListener
      ..listen((event) {
        print("voip-onCallStateChanged $event");

        switch (event) {
          case CallEvent.answer:
            //at this point android is still paused
            if (Platform.isIOS && state == null ||
                state == AppLifecycleState.resumed) {
              pushToCallScreen();
              hasPushedToCall = true;
            }
            break;
          case CallEvent.ringing:
            final activeCall = TwilioVoice.instance.call.activeCall;
            if (activeCall != null) {
              final customData = activeCall.customParams;
              if (customData != null) {
                print("voip-customData $customData");
              }
            }
            break;
          case CallEvent.connected:
            if (Platform.isAndroid &&
                TwilioVoice.instance.call.activeCall!.callDirection ==
                    CallDirection.incoming) {
              if (state != AppLifecycleState.resumed) {
                TwilioVoice.instance.showBackgroundCallUI();
              } else if (state == null || state == AppLifecycleState.resumed) {
                pushToCallScreen();
                hasPushedToCall = true;
              }
            }
            break;
          case CallEvent.callEnded:
            hasPushedToCall = false;
            break;
          case CallEvent.returningCall:
            pushToCallScreen();
            hasPushedToCall = true;
            break;
          default:
            break;
        }
      });
  }

  AppLifecycleState? state;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    this.state = state;
    print("didChangeAppLifecycleState");
    if (state == AppLifecycleState.resumed) {
      checkActiveCall();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _controller,
                  decoration: InputDecoration(
                      labelText: 'Client Identifier or Phone Number'),
                ),
                SizedBox(
                  height: 10,
                ),
                ElevatedButton(
                  child: Text("Make Call"),
                  onPressed: () async {
                    if (!await (TwilioVoice.instance.hasMicAccess())) {
                      print("request mic access");
                      TwilioVoice.instance.requestMicAccess();
                      return;
                    }
                    print("starting call to ${_controller.text}");
                    TwilioVoice.instance.call
                        .place(to: _controller.text, from: "testChristo");
                    pushToCallScreen();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void pushToCallScreen() {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        fullscreenDialog: true, builder: (context) => CallScreen()));
  }
}
