import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
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
        debugShowCheckedModeBanner: false,
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
  bool _isNavRailVisible = true;

  void _toggleNavRail() {
    setState(() {
      _isNavRailVisible = !_isNavRailVisible;
    });
  }

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
        throw UnimplementedError('No widget for $selectedIndex');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: Row(
            children: [
              // NavigationRail section
              SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >= 600 && _isNavRailVisible, // Extend when wide enough and visible
                  leading: Column(
                    children: [
                      IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: _toggleNavRail,
                      ),
                      const SizedBox(height: 8),
                      // Ensure the logo is always visible
                      Image.asset(
                        'assets/logo.png', // Replace with your image path
                        width: _isNavRailVisible ? 60 : 30, // Adjust size when minimized
                        height: _isNavRailVisible ? 60 : 30, // Adjust size when minimized
                      ),
                      if (_isNavRailVisible) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'PassForge',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.key_rounded), // Icon always visible
                      label: Text('Generator'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined), // Icon always visible
                      label: Text('Password Storage'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.manage_history), // Icon always visible
                      label: Text('History'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings), // Icon always visible
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
              // Main content area
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: page,
                ),
              ),
            ],
          ),
        );
      },
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
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto', //To change the font of the text
              )
            ),
            const SizedBox(height: 35),
            DropdownButton<int>(
              value: appState.length,
              items: [8, 12, 16, 20, 24].map<DropdownMenuItem<int>>((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                    child: Text(
                    '$value characters',
                    style: const TextStyle(
                      fontSize: 18, // Change the size of the text
                      fontWeight: FontWeight.w500, // Make the text bold
                    ),
                  ),
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
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Comic Sans MS', //To change the font of the text
              ),
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
                  style: ElevatedButton.styleFrom(
                    alignment: Alignment.centerLeft, // or centerRight
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CredentialStoragePage extends StatefulWidget {
  const CredentialStoragePage({super.key});

  @override
  _CredentialStoragePageState createState() => _CredentialStoragePageState();
}

class _CredentialStoragePageState extends State<CredentialStoragePage> {
  // Set to track which credentials have their passwords revealed
  final Set<String> _revealedPasswords = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MyAppState>(context, listen: false).loadStoredCredentials();
    });
  }

  void _togglePasswordVisibility(String serviceName) {
    setState(() {
      if (_revealedPasswords.contains(serviceName)) {
        _revealedPasswords.remove(serviceName);
      } else {
        _revealedPasswords.add(serviceName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    if (appState.storedCredentials.isEmpty) {
      return const Center(
        child: Text('No credentials stored'),
      );
    }

    return ListView.builder(
      itemCount: appState.storedCredentials.length,
      itemBuilder: (context, index) {
        final credential = appState.storedCredentials[index];
        final serviceName = credential['serviceName'] ?? 'Unknown Service';
        final username = credential['username'] ?? 'Unknown Username';
        final password = credential['password'] ?? '';
        final isPasswordRevealed = _revealedPasswords.contains(serviceName);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            title: Text(serviceName),
            subtitle: Text(username),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isPasswordRevealed ? password : '*' * password.length,
                        style: const TextStyle(letterSpacing: 2),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isPasswordRevealed 
                          ? Icons.visibility_off 
                          : Icons.visibility,
                      ),
                      onPressed: () => _togglePasswordVisibility(serviceName),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Credential'),
                          content: Text('Are you sure you want to delete credentials for $serviceName?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                appState.deleteCredential(serviceName);
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}