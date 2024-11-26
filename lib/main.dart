import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:passforge/savedata.dart';
import 'secure_credential_manager.dart';

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
          colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 255, 98, 0)),
        ),
        home: const MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  String _password = '';
  int _length = 12; // Default password length
  List<Map<String, String>> _storedCredentials = []; // Add this line

  String get password => _password;
  int get length => _length;
  List<Map<String, String>> get storedCredentials => _storedCredentials; // Optional getter
  final SecureCredentialManager _credentialManager = SecureCredentialManager();

  // Modify these methods to match the new implementation
  Future<void> addCredential({
    required String serviceName, 
    required String username, 
    required String password
  }) async {
    print('MyAppState: Adding credential for $serviceName');
    await _credentialManager.storeCredential(
      serviceName: serviceName, 
      username: username, 
      password: password
    );
    await loadStoredCredentials();
  }
  Future<void> loadStoredCredentials() async {
    print('MyAppState: Loading stored credentials');
    _storedCredentials = await _credentialManager.retrieveCredentials();
    print('MyAppState: Loaded ${_storedCredentials.length} credentials');
    notifyListeners();
  }

  Future<void> deleteCredential(String serviceName) async {
    print('MyAppState: Deleting credential for $serviceName');
    await _credentialManager.deleteCredential(serviceName);
    await loadStoredCredentials();
  }

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
  /*
  var passwords = <WordPair>[];
  void addpasswords() {
    if (passwords.contains(chars)) {
      passwords.remove(chars);
    } else {
      passwords.add(current);
    }
    notifyListeners();
  }*/
}
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = const PasswordGeneratorPage();
        break;
      case 1:
        page = const CredentialStoragePage();
        break;
      case 2:
        page = const Placeholder();
        break;
      case 3:
        page = const Placeholder();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >= 600,
                  leading: Column(
                    children: [
                      // Custom image with fixed size
                      Image.asset(
                        'assets/logo.png', // Replace with your image path
                        width: 60,
                        height: 60,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'PassForge', 
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.key_rounded),
                      label: Text('Generator'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      label: Text('Password Storage'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.manage_history),
                      label: Text('History'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings),
                      label: Text('Settings'),
                    ),
                  ],
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (value) {
                    setState(() {
                      selectedIndex = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: page,
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

class PasswordGeneratorPage extends StatelessWidget {
  const PasswordGeneratorPage({super.key});

  void _showSaveCredentialDialog(BuildContext context, String password) {
    final serviceNameController = TextEditingController();
    final usernameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save Credential'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: serviceNameController,
                decoration: const InputDecoration(
                  labelText: 'Service Name',
                  hintText: 'e.g., Google, Facebook',
                ),
              ),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your username',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Get the app state
                final appState = Provider.of<MyAppState>(context, listen: false);
                
                // Save the credential
                appState.addCredential(
                  serviceName: serviceNameController.text.trim(),
                  username: usernameController.text.trim(),
                  password: password,
                );

                // Close the dialog
                Navigator.of(context).pop();

                // Show a confirmation snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Credential saved for ${serviceNameController.text}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    
    return Center(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    appState.generateRandomPassword();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Generate New Password'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _showSaveCredentialDialog(context, appState.password);
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save Password'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/*
class display extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    if (appState.passwords.isEmpty) {
      return Center(
        child: Text('No passwords yet.'),
      );
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('You have '
              '${appState.passwords.length} favorites:'),
        ),
        for (var pair in appState.favorites)
          ListTile(
            leading: Icon(Icons.favorite),
            title: Text(pair.asLowerCase),
          ),
      ],
    );
  }
}*/

class CredentialStoragePage extends StatefulWidget {
  const CredentialStoragePage({super.key});

  @override
  _CredentialStoragePageState createState() => _CredentialStoragePageState();
}

class _CredentialStoragePageState extends State<CredentialStoragePage> {
  @override
  void initState() {
    super.initState();
    print('CredentialStoragePage initState called');
    
    // Use a slight delay to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<MyAppState>(context, listen: false);
      print('Attempting to load credentials');
      appState.loadStoredCredentials().then((_) {
        print('Credentials loaded. Count: ${appState.storedCredentials.length}');
      }).catchError((error) {
        print('Error loading credentials: $error');
      });
    });
  }
   void _addTestCredential() {
    final appState = Provider.of<MyAppState>(context, listen: false);
    appState.addCredential(
      serviceName: 'TestService',
      username: 'testuser',
      password: 'testpassword'
    );
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    
    print('Building CredentialStoragePage');
    print('Stored credentials count: ${appState.storedCredentials.length}');

    if (appState.storedCredentials.isEmpty) {
      return const Center(
        child: Text('No credentials stored'),
      );
    }

    return ListView.builder(
      itemCount: appState.storedCredentials.length,
      itemBuilder: (context, index) {
        final credential = appState.storedCredentials[index];
        return ListTile(
          title: Text(credential['serviceName'] ?? 'Unknown Service'),
          subtitle: Text(credential['username'] ?? 'Unknown Username'),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              appState.deleteCredential(credential['serviceName']!);
            },
          ),
        );
      },
    );
  }
}
