import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'secure_credential_manager.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: Consumer<MyAppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'PassForge',
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color.fromARGB(255, 255, 98, 0),
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color.fromARGB(255, 255, 98, 0),
                brightness: Brightness.dark,
              ),
            ),
            themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const MyHomePage(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  String _password = '';
  int _length = 12;
  List<Map<String, String>> _storedCredentials = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> _unsavedPasswords = []; // Keeps track of unsaved passwords with timestamps
  List<Map<String, dynamic>> get unsavedPasswords => _unsavedPasswords;

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
  void addUnsavedPassword(String password) {
    final timestamp = DateTime.now();
    _unsavedPasswords.add({'password': password, 'timestamp': timestamp});
    notifyListeners();

    // Remove expired passwords automatically after 10 minutes
    Future.delayed(const Duration(minutes: 10), () {
      _unsavedPasswords.removeWhere((item) =>
          DateTime.now().difference(item['timestamp']).inMinutes >= 10);
      notifyListeners();
    });
  }

  void removeUnsavedPassword(String password) {
    _unsavedPasswords.removeWhere((item) => item['password'] == password);
    notifyListeners();
  }

  void saveUnsavedPassword(String password, String serviceName, String username) {
    removeUnsavedPassword(password);
    addCredential(
      serviceName: serviceName,
      username: username,
      password: password,
    );
  }
  void deleteUnsavedPassword(String password) {
    _unsavedPasswords.removeWhere((item) => item['password'] == password);
    notifyListeners();
  }
   bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
   bool _isAuthenticationEnabled = true;
  bool get isAuthenticationEnabled => _isAuthenticationEnabled;

  void toggleAuthentication(bool value) {
    _isAuthenticationEnabled = value;
    notifyListeners();
  }

  Future<bool> authenticateUser() async {
    if (!_isAuthenticationEnabled) return true;

    final LocalAuthentication localAuth = LocalAuthentication();

    try {
      // Check for device authentication capabilities
      bool canAuthenticate = await localAuth.canCheckBiometrics || await localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        return false;
      }

      // Attempt authentication
      final bool didAuthenticate = await localAuth.authenticate(
        localizedReason: 'Please authenticate to access your passwords',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      return didAuthenticate;
    } catch (e) {
      print('Authentication error: $e');
      return false;
    }
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
        return Scaffold(
          appBar: selectedIndex != 3 // Hide AppBar in Settings page
              ? AppBar(
                  title: Row(
                    children: [
                      Image.asset(
                        'assets/logo.png', // Replace with your logo asset path
                        width: 40, 
                        height: 40,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'PassForge',
                        style: TextStyle(
                          fontFamily: 'BungeeSpice', // Replace 'CustomFont' with the name of your font
                          fontSize: 20, // Adjust font size as needed
                          fontWeight: FontWeight.bold, // Adjust weight as needed
                        ),
                      ),
                    ],
                  ),
                )
              : null,
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
  void _generatePassword(BuildContext context) {
    var appState = Provider.of<MyAppState>(context, listen: false);
    appState.generateRandomPassword();
    appState.addUnsavedPassword(appState.password);
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
                  fontFamily: 'BungeeSpice',
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
                    onPressed: () => _generatePassword(context),
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
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MyAppState>(context, listen: false).loadStoredCredentials();
    });
  }

  void _togglePasswordVisibility(String serviceName) async {
    var appState = Provider.of<MyAppState>(context, listen: false);

    // Check authentication if it's enabled
    if (appState.isAuthenticationEnabled && !_isAuthenticating) {
      setState(() {
        _isAuthenticating = true;
      });

      bool authenticated = await appState.authenticateUser();

      setState(() {
        _isAuthenticating = false;
      });

      if (!authenticated) {
        return;
      }
    }

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
    return AuthenticatedPage(
      child: SafeArea(
        child: Consumer<MyAppState>(
          builder: (context, appState, child) {
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

            return RefreshIndicator(
              onRefresh: () => appState.loadStoredCredentials(),
              child: ListView.builder(
                itemCount: appState.storedCredentials.length,
                itemBuilder: (context, index) {
                  final credential = appState.storedCredentials[index];
                  final serviceName = credential['serviceName'] ?? 'Unknown Service';
                  final username = credential['username'] ?? '';
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
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: ListTile(
                        title: Text(
                          serviceName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Username: $username'),
                            if (isPasswordRevealed)
                              Text(
                                'Password: $password',
                                style: const TextStyle(color: Colors.green),
                              )
                            else
                              const Text(
                                'Password: ●●●●●●●●',
                                style: TextStyle(color: Colors.grey),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isPasswordRevealed ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => _togglePasswordVisibility(serviceName),
                        ),
                      ),
                    ),
                  );
                },
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

  void _showSaveDialog(BuildContext context, String password) {
    final serviceNameController = TextEditingController();
    final usernameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save Unsaved Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: serviceNameController,
                  decoration: const InputDecoration(
                    labelText: 'Service Name',
                  ),
                ),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
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
                if (serviceNameController.text.trim().isNotEmpty &&
                    usernameController.text.trim().isNotEmpty) {
                  var appState = Provider.of<MyAppState>(context, listen: false);
                  appState.saveUnsavedPassword(
                    password,
                    serviceNameController.text.trim(),
                    usernameController.text.trim(),
                  );

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Password saved for ${serviceNameController.text}'),
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
    return AuthenticatedPage(
      child: SafeArea(
        child: Consumer<MyAppState>(
          builder: (context, appState, child) {
            if (appState.unsavedPasswords.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No unsaved passwords in history',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: appState.unsavedPasswords.length,
              itemBuilder: (context, index) {
                final unsavedPassword = appState.unsavedPasswords[index];
                final password = unsavedPassword['password'];
                final timestamp = unsavedPassword['timestamp'] as DateTime;

                return Dismissible(
                  key: Key(password),
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
                        title: const Text('Delete Password'),
                        content: Text('Are you sure you want to delete this password?'),
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
                    appState.deleteUnsavedPassword(password);
                  },
                  child: ListTile(
                    title: Text(
                      password,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    subtitle: Text(
                      'Generated: ${timestamp.toLocal()}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.save, color: Colors.orange),
                          onPressed: () => _showSaveDialog(context, password),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.blue),
                          onPressed: () {
                            // TODO: Implement copy to clipboard functionality
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}


void _showSaveDialog(BuildContext context, String password) {
  final serviceNameController = TextEditingController();
  final usernameController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Save Unsaved Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: serviceNameController,
                decoration: const InputDecoration(
                  labelText: 'Service Name',
                ),
              ),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
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
              if (serviceNameController.text.trim().isNotEmpty &&
                  usernameController.text.trim().isNotEmpty) {
                var appState = Provider.of<MyAppState>(context, listen: false);
                appState.saveUnsavedPassword(
                  password,
                  serviceNameController.text.trim(),
                  usernameController.text.trim(),
                );

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Password saved for ${serviceNameController.text}'),
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


class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                title: const Text('Dark Mode'),
                subtitle: Text(appState.isDarkMode ? 'Enabled' : 'Disabled'),
                trailing: Switch(
                  value: appState.isDarkMode,
                  onChanged: (bool value) {
                    appState.toggleTheme();
                  },
                ),
              ),
            ),
            const Spacer(),
            const Text(
              'PassForge v1.1',
              style: TextStyle(
                fontFamily: 'BungeeSpice',
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthenticatedPage extends StatefulWidget {
  final Widget child;

  const AuthenticatedPage({super.key, required this.child});

  @override
  _AuthenticatedPageState createState() => _AuthenticatedPageState();
}

class _AuthenticatedPageState extends State<AuthenticatedPage> {
  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    var appState = Provider.of<MyAppState>(context, listen: false);
    bool authenticated = true;
    if (appState.isAuthenticationEnabled) {
      bool authenticated = await appState.authenticateUser();
      if (!authenticated) {
        // Navigate back if authentication fails
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}