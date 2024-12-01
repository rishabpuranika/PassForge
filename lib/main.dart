import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'secure_credential_manager.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:io';


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
            themeMode: appState.isPreferencesReady 
              ? (appState.isDarkMode ? ThemeMode.dark : ThemeMode.light)
              : ThemeMode.light, // Default to light theme during initialization
            home: const MyHomePage(), //to set the home page
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  String _password = '';
  int _length = 12; // Default password length
  List<Map<String, String>> _storedCredentials = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> _unsavedPasswords = []; // Keeps track of unsaved passwords with timestamps
  List<Map<String, dynamic>> get unsavedPasswords => _unsavedPasswords;

  String get password => _password;
  int get length => _length;
  List<Map<String, String>> get storedCredentials => _storedCredentials;
  bool get isLoading => _isLoading; 

  SharedPreferences? _prefs;
  bool _isDarkMode = false;
  bool _isInitialized = false;

  //initialize defaults for the app like stored passwords and preferences
  MyAppState() {
    _initializePreferences().then((_) {
    _loadUnsavedPasswordsFromPrefs();
    loadStoredCredentials();
    });
  }

  final SecureCredentialManager _credentialManager = SecureCredentialManager();
  
  // Add a method to store credentials securely
  Future<void> addCredential({
    required String serviceName, 
    required String username, 
    required String password
  }) async {
    try {
      _isLoading = true;
      if (password=="") {
        throw Exception('Password cannot be empty');
      }
      await _credentialManager.storeCredential(
        serviceName: serviceName, 
        username: username, 
        password: password
      );
      await loadStoredCredentials();
    } catch (e) {
      // ignore: avoid_print
      print('Error adding credential: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  // Add a method to load stored credentials
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
  // Add a method to delete stored credentials
  Future<void> deleteCredential(Map<String, String> credential) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _credentialManager.deleteCredential(
        serviceName: credential['serviceName'] ?? '',
        username: credential['username'] ?? '',
        timestamp: credential['timestamp'] ?? ''
      );
      await loadStoredCredentials();
    } catch (e) {
      print('Error deleting credential: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a method to set the password length
  void setLength(int newLength) {
    _length = newLength;
    //generateRandomPassword();
    _password='';
    notifyListeners();
  }
  // Add a method to generate a random password
  void generateRandomPassword() {
    const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*()";
    Random random = Random();
    _password = String.fromCharCodes(
      Iterable.generate(_length, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
    notifyListeners();
  }
  // Add a method to add unsaved passwords
  void addUnsavedPassword(String password) {
    final timestamp = DateTime.now();
    _unsavedPasswords.add({'password': password, 'timestamp': timestamp});
    _saveUnsavedPasswordsToPrefs(); // Add this line
    notifyListeners();
    // Remove expired passwords automatically after 10 minutes
     Future.delayed(const Duration(minutes: 10), () {
    _unsavedPasswords.removeWhere((item) =>
        DateTime.now().difference(item['timestamp']).inMinutes >= 10);
    _saveUnsavedPasswordsToPrefs(); // Add this line
    notifyListeners();
    });
  }
  // Add a method to remove unsaved passwords
  void removeUnsavedPassword(String password) {
  _unsavedPasswords.removeWhere((item) => item['password'] == password);
  _saveUnsavedPasswordsToPrefs(); // Add this line
  notifyListeners();
  }
  // Add a method to save unsaved passwords
  void saveUnsavedPassword(String password, String serviceName, String username) {
    removeUnsavedPassword(password);
    addCredential(
      serviceName: serviceName,
      username: username,
      password: password,
    );
  }
  // Add a method to delete unsaved passwords
  void deleteUnsavedPassword(String password) {
  _unsavedPasswords.removeWhere((item) => item['password'] == password);
  _saveUnsavedPasswordsToPrefs(); // Add this line
  notifyListeners();
  }
  // Add a method to initialize preferences for the theme like dark or light mode
  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs?.getBool('isDarkMode') ?? false;
    _isInitialized = true;
    notifyListeners();
  }
  // Add a method to save unsaved passwords to persistent storage
  Future<void> _saveUnsavedPasswordsToPrefs() async {
  if (_prefs != null) {
    List<String> passwordsJson = _unsavedPasswords.map((item) => 
      jsonEncode({
        'password': item['password'],
        'timestamp': item['timestamp'].toIso8601String()
      })
    ).toList();
    await _prefs!.setStringList('unsavedPasswords', passwordsJson);
    }
  }

// Add a method to load unsaved passwords from persistent storage
  Future<void> _loadUnsavedPasswordsFromPrefs() async {
    if (_prefs != null) {
      List<String>? passwordsJson = _prefs!.getStringList('unsavedPasswords');
      if (passwordsJson != null) {
        _unsavedPasswords = passwordsJson.map((json) {
          var item = jsonDecode(json);
          return {
            'password': item['password'],
            'timestamp': DateTime.parse(item['timestamp'])
          };
        }).toList();
      }
    }
  }
  // Add a method to toggle the theme
  void toggleTheme() {
    // Ensure _prefs is not null before using it
    if (_prefs != null) {
      _isDarkMode = !_isDarkMode;
      _prefs!.setBool('isDarkMode', _isDarkMode);
      notifyListeners();
    }
  }

  // Modify the getter to handle uninitialized state
  bool get isDarkMode {
    return _isDarkMode;
  }

  // Add a method to check if preferences are ready
  bool get isPreferencesReady => _isInitialized;
  // Add a method to check if authentication is enabled
  bool _isAuthenticationEnabled = true; // Default to true)(as i have removed the authentication part for security reasons)
  bool get isAuthenticationEnabled => _isAuthenticationEnabled;

  void toggleAuthentication(bool value) {
    _isAuthenticationEnabled = value;
    notifyListeners();
  }
  // Add a method to authenticate the user
  Future<bool> authenticateUser(BuildContext context) async {
  if (!_isAuthenticationEnabled) return true;

  final LocalAuthentication localAuth = LocalAuthentication();

  try {
    // Check for device authentication capabilities
    bool canAuthenticate = await localAuth.canCheckBiometrics || await localAuth.isDeviceSupported();

    if (!canAuthenticate) {
      // Show a dialog explaining authentication is not possible
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
  } on PlatformException catch (e) {
    // Handle specific authentication errors
    switch (e.code) {
      case auth_error.notEnrolled:
        // Show dialog: No biometrics enrolled
        _showAuthenticationDialog(
          context, 
          'No Biometrics',
          'Please set up biometrics in your device settings.'
        );
        break;
      case auth_error.passcodeNotSet:
        // Show dialog: No passcode set
        _showAuthenticationDialog(
          context, 
          'Passcode Required',
          'Please set up a device passcode.'
        );
        break;
      case auth_error.permanentlyLockedOut:
        // Serious lockout - suggest device settings
        _showAuthenticationDialog(
          context, 
          'Authentication Locked',
          'Too many failed attempts. Reset in device settings.'
        );
        break;
      default:
        print('Unhandled auth error: ${e.code}');
    }
    return false;
  } catch (e) {
    print('Unexpected authentication error: $e');
    return false;
  }
}
}
  // Add a method to show an authentication dialog
  void _showAuthenticationDialog(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
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
          appBar: selectedIndex != 3 // Hide AppBar in Settings page and in this case the bar wont be displayed in 3rd page which is settings
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
            // Add more items as needed for the navigation bar present in the bottom this contains icons
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
  // Add a method to build the page based on the selected index connecting to the above icons
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
  // Add a method to show a dialog to save the credential
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
                    hintText: 'e.g., Google, Meta, etc.',
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
                  // Show a snackbar(notification message) to confirm the credential was saved
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
  // Add a method to generate a password
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
  final Set<String> _revealedCredentials = {};
  bool _isAuthenticating = false;
  // Add a method to copy credentials to the clipboard
  void _copyToClipboard(String text, String serviceName) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$serviceName credential copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  // Add a method to toggle credential visibility
  void _toggleCredentialVisibility(String serviceName) async {
    var appState = Provider.of<MyAppState>(context, listen: false);

    // Check authentication if it's enabled
    if (appState.isAuthenticationEnabled && !_isAuthenticating) {
      setState(() {
        _isAuthenticating = true;
      });

      bool authenticated = await appState.authenticateUser(context);

      setState(() {
        _isAuthenticating = false;
      });

      if (!authenticated) {
        if (Platform.isAndroid || Platform.isIOS) {
          // For mobile platforms
          exit(0);
        }
      }
    }

    setState(() {
      if (_revealedCredentials.contains(serviceName)) {
        _revealedCredentials.remove(serviceName);
      } else {
        _revealedCredentials.add(serviceName);
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
                  final isCredentialsRevealed = _revealedCredentials.contains(serviceName);

                  return Dismissible(
                    key: Key('${credential['serviceName']}_${credential['username']}_${credential['timestamp']}'),
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
                      appState.deleteCredential(credential);
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
                            Text(
                              'Username: ${isCredentialsRevealed ? username : '●●●●●●●●'}',
                              style: TextStyle(
                                color: isCredentialsRevealed ? const Color.fromARGB(255, 30, 153, 11) : Colors.grey,
                              ),
                            ),
                            Text(
                              'Password: ${isCredentialsRevealed ? password : '●●●●●●●●'}',
                              style: TextStyle(
                                color: isCredentialsRevealed ? const Color.fromARGB(255, 252, 17, 0) : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isCredentialsRevealed 
                                  ? Icons.visibility 
                                  : Icons.visibility_off,
                              ),
                              onPressed: () => _toggleCredentialVisibility(serviceName),
                            ),
                            if (isCredentialsRevealed) ...[
                              IconButton(
                                icon: const Icon(Icons.copy, color: Color.fromARGB(255, 30, 153, 11)),
                                onPressed: () {
                                  _copyToClipboard(username, '$serviceName username');
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, color: Color.fromARGB(255, 252, 17, 0)),
                                onPressed: () {
                                  _copyToClipboard(password, '$serviceName password');
                                },
                              ),
                            ],
                          ],
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

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final Set<String> _revealedPasswords = {};
  // Add a method to show a dialog to save unsaved passwords
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
  // Add a method to toggle password visibility
  void _togglePasswordVisibility(String password) {
    setState(() {
      if (_revealedPasswords.contains(password)) {
        _revealedPasswords.remove(password);
      } else {
        _revealedPasswords.add(password);
      }
    });
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
                final isPasswordRevealed = _revealedPasswords.contains(password);

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
                      isPasswordRevealed 
                        ? password 
                        : '*' * password.length, // Show stars or actual password
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
                          icon: Icon(
                            isPasswordRevealed 
                              ? Icons.visibility 
                              : Icons.visibility_off,
                          ),
                          onPressed: () => _togglePasswordVisibility(password),
                        ),
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
                subtitle: Text(appState._isDarkMode ? 'Enabled' : 'Disabled'),
                trailing: Switch(
                  value: appState._isDarkMode,
                  onChanged: (bool value) {
                    appState.toggleTheme();
                  },
                ),
              ),
            ),
            const Spacer(),
            const Text(
              'PassForge v1.2',
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
      authenticated = await appState.authenticateUser(context);
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