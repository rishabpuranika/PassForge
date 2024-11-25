import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'PassForge',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 0, 0, 0)),
        ),
        home: const MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  String _password = '';
  int _length = 12; // Default password length

  String get password => _password;
  int get length => _length;

  void setLength(int newLength) {
    _length = newLength;
    generateRandomPassword();
  }

  void generateRandomPassword() {
    const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*()";
    Random random = Random();
    _password = String.fromCharCodes(
      Iterable.generate(_length, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
    notifyListeners();
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('PassForge'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Select the length of your password:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              DropdownButton<int>(
                value: appState.length,
                items: [8, 12, 16, 20, 24].map<DropdownMenuItem<int>>((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value characters'),
                  );
                }).toList(),
                onChanged: (int? value) {
                  if (value != null) {
                    appState.setLength(value);
                  }
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'Your password is:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              SelectableText(
                appState.password,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  appState.generateRandomPassword();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Generate New Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}