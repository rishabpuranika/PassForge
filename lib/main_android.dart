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
  int _length = 12;
  List<Map<String, String>> _storedCredentials = [];
  bool _isLoading = false;

  String get password => _password;
  int get length => _length;
  List<Map<String, String>> get storedCredentials => _storedCredentials;
  bool get isLoading => _isLoading;

  final SecureCredentialManager _credentialManager = SecureCredentialManager();

  Future<void> addCredential({
    required String serviceName, 
    required String username, 
    required String password
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _credentialManager.storeCredential(
        serviceName: serviceName, 
        username: username, 
        password: password
      );
      await loadStoredCredentials();
    } catch (e) {
      print('Error adding credential: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStoredCredentials() async {
    try {
      _isLoading = true;
      notifyListeners();

      _storedCredentials = await _credentialManager.retrieveCredentials();
    } catch (e) {
      print('Error loading credentials: $e');
      _storedCredentials = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteCredential(String serviceName) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _credentialManager.deleteCredential(serviceName);
      await loadStoredCredentials();
    } catch (e) {
      print('Error deleting credential: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use BottomNavigationBar for mobile-friendly navigation
        return Scaffold(
          body: _buildPage(selectedIndex),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: selectedIndex,
            onTap: (value) {
              setState(() {
                selectedIndex = value;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.key_rounded),
                label: 'Generator',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                label: 'Storage',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.manage_history),
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const PasswordGeneratorPage();
      case 1:
        return const CredentialStoragePage();
      case 2:
        return const HistoryPage();
      case 3:
        return const SettingsPage();
      default:
        return const PasswordGeneratorPage();
    }
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
          content: SingleChildScrollView(
            child: Column(
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final appState = Provider.of<MyAppState>(context, listen: false);
                
                if (serviceNameController.text.trim().isNotEmpty &&
                    usernameController.text.trim().isNotEmpty) {
                  appState.addCredential(
                    serviceName: serviceNameController.text.trim(),
                    username: usernameController.text.trim(),
                    password: password,
                  );

                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Credential saved for ${serviceNameController.text}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all fields'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
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
    
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Select the length of your password:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              DropdownButton<int>(
                value: appState.length,
                items: [8, 12, 16, 20, 24].map<DropdownMenuItem<int>>((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(
                      '$value characters',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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
              const SizedBox(height: 20),
              const Text(
                'Your password is:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(
                appState.password,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      appState.generateRandomPassword();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Generate'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      _showSaveCredentialDialog(context, appState.password);
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  )
                ],
              ),
            ],
          ),
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

    if (appState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (appState.storedCredentials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_open, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No credentials stored',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => appState.loadStoredCredentials(),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: appState.storedCredentials.length,
          itemBuilder: (context, index) {
            final credential = appState.storedCredentials[index];
            final serviceName = credential['serviceName'] ?? 'Unknown Service';
            final username = credential['username'] ?? 'Unknown Username';
            final password = credential['password'] ?? '';
            final isPasswordRevealed = _revealedPasswords.contains(serviceName);

            return Dismissible(
              key: Key(serviceName),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                return await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Credential'),
                    content: Text('Are you sure you want to delete credentials for $serviceName?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (direction) {
                appState.deleteCredential(serviceName);
              },
              child: Card(
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
                              overflow: TextOverflow.ellipsis,
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
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Placeholder pages for History and Settings
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('History Page (Coming Soon)'));
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Settings Page (Coming Soon)'));
  }
}