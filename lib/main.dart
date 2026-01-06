import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LicenseStatus { trial, licensed, expired }

class LicenseManager {
  static const String _firstRunKey = 'app_first_run';
  static const String _licenseKey = 'app_license';
  static const int trialDays = 5;

  static Future<LicenseStatus> checkLicense() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_licenseKey) != null) return LicenseStatus.licensed;
    final firstRun = prefs.getString(_firstRunKey);
    if (firstRun == null) {
      await prefs.setString(_firstRunKey, DateTime.now().toIso8601String());
      return LicenseStatus.trial;
    }
    final startDate = DateTime.parse(firstRun);
    final daysUsed = DateTime.now().difference(startDate).inDays;
    return daysUsed < trialDays ? LicenseStatus.trial : LicenseStatus.expired;
  }

  static Future<int> getRemainingDays() async {
    final prefs = await SharedPreferences.getInstance();
    final firstRun = prefs.getString(_firstRunKey);
    if (firstRun == null) return trialDays;
    final startDate = DateTime.parse(firstRun);
    final daysUsed = DateTime.now().difference(startDate).inDays;
    return (trialDays - daysUsed).clamp(0, trialDays);
  }

  static Future<bool> activate(String key) async {
    final cleaned = key.trim().toUpperCase();
    if (cleaned.length == 19 && cleaned.contains('-')) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_licenseKey, cleaned);
      return true;
    }
    return false;
  }
}

class TrialBanner extends StatelessWidget {
  final int daysRemaining;
  const TrialBanner({super.key, required this.daysRemaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: daysRemaining <= 2 ? Colors.red : Colors.orange,
      child: Text(
        'Periodo de teste: ' + daysRemaining.toString() + ' dias restantes',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class LicenseExpiredScreen extends StatefulWidget {
  const LicenseExpiredScreen({super.key});
  @override
  State<LicenseExpiredScreen> createState() => _LicenseExpiredScreenState();
}

class _LicenseExpiredScreenState extends State<LicenseExpiredScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _activate() async {
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 500));
    final ok = await LicenseManager.activate(_ctrl.text);
    if (ok && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RestartApp()));
    } else if (mounted) {
      setState(() { _error = 'Chave invalida'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.red.shade800, Colors.red.shade600], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 80, color: Colors.white),
                const SizedBox(height: 24),
                const Text('Periodo de Teste Encerrado', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 32),
                TextField(controller: _ctrl, decoration: InputDecoration(labelText: 'Chave de Licenca', hintText: 'XXXX-XXXX-XXXX-XXXX', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), errorText: _error), textCapitalization: TextCapitalization.characters, maxLength: 19),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _activate, style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.green), child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Ativar', style: TextStyle(fontSize: 18, color: Colors.white)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RestartApp extends StatelessWidget {
  const RestartApp({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([LicenseManager.checkLicense(), LicenseManager.getRemainingDays()]),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return MyApp(licenseStatus: snap.data![0] as LicenseStatus, remainingDays: snap.data![1] as int);
      },
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final status = await LicenseManager.checkLicense();
  final days = await LicenseManager.getRemainingDays();
  runApp(MyApp(licenseStatus: status, remainingDays: days));
}

class MyApp extends StatelessWidget {
  final LicenseStatus licenseStatus;
  final int remainingDays;
  const MyApp({super.key, required this.licenseStatus, required this.remainingDays});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true),
      home: licenseStatus == LicenseStatus.expired ? const LicenseExpiredScreen() : HomeScreen(licenseStatus: licenseStatus, remainingDays: remainingDays),
    );
  }
}

class Recipe {
  final String name;
  final String description;
  final int prepTime;
  final List<String> ingredients;

  Recipe({required this.name, required this.description, required this.prepTime, required this.ingredients});
}

class HomeScreen extends StatefulWidget {
  final LicenseStatus licenseStatus;
  final int remainingDays;
  const HomeScreen({super.key, required this.licenseStatus, required this.remainingDays});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> detectedIngredients = [];
  List<Recipe> suggestedRecipes = [];
  bool isAnalyzing = false;

  final List<Recipe> allRecipes = [
    Recipe(name: 'Omelete Simples', description: 'Omelete cremoso com temperos', prepTime: 10, ingredients: ['ovos', 'leite', 'sal', 'pimenta']),
    Recipe(name: 'Salada Verde', description: 'Salada refrescante com folhas', prepTime: 5, ingredients: ['alface', 'tomate', 'azeite', 'sal']),
    Recipe(name: 'Sanduiche Natural', description: 'Sanduiche saudavel e nutritivo', prepTime: 8, ingredients: ['pao', 'queijo', 'tomate', 'alface']),
    Recipe(name: 'Vitamina de Banana', description: 'Bebida energetica natural', prepTime: 3, ingredients: ['banana', 'leite', 'mel']),
    Recipe(name: 'Pasta de Atum', description: 'Pasta cremosa para lanches', prepTime: 5, ingredients: ['atum', 'maionese', 'cebola', 'sal']),
    Recipe(name: 'Arroz Temperado', description: 'Arroz saboroso e facil', prepTime: 15, ingredients: ['arroz', 'cebola', 'alho', 'oleo']),
  ];

  void _simulatePhotoAnalysis() async {
    setState(() {
      isAnalyzing = true;
      detectedIngredients = [];
      suggestedRecipes = [];
    });

    await Future.delayed(const Duration(seconds: 2));

    final mockIngredients = ['ovos', 'leite', 'tomate', 'queijo', 'pao', 'banana'];
    setState(() {
      detectedIngredients = mockIngredients.take(4).toList();
      isAnalyzing = false;
    });

    _generateRecipeSuggestions();
  }

  void _generateRecipeSuggestions() {
    final recipes = allRecipes.where((recipe) {
      return recipe.ingredients.any((ingredient) => detectedIngredients.contains(ingredient));
    }).take(3).toList();

    setState(() {
      suggestedRecipes = recipes;
    });
  }

  void _showRecipeDetails(Recipe recipe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recipe.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recipe.description),
            const SizedBox(height: 12),
            Text('Tempo: ${recipe.prepTime} minutos', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Ingredientes:', style: TextStyle(fontWeight: FontWeight.bold)),
            for (String ingredient in recipe.ingredients)
              Text('• $ingredient'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receitas da Geladeira'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          if (widget.licenseStatus == LicenseStatus.trial)
            TrialBanner(daysRemaining: widget.remainingDays),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.camera_alt, size: 60, color: Colors.blue),
                          const SizedBox(height: 16),
                          const Text('Tire uma foto dos ingredientes da sua geladeira', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: isAnalyzing ? null : _simulatePhotoAnalysis,
                            icon: const Icon(Icons.photo_camera),
                            label: Text(isAnalyzing ? 'Analisando...' : 'Tirar Foto'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(12),
                              minimumSize: const Size(200, 50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isAnalyzing)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Identificando ingredientes...'),
                          ],
                        ),
                      ),
                    ),
                  if (detectedIngredients.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ingredientes Detectados:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: detectedIngredients.map((ingredient) => Chip(
                                label: Text(ingredient),
                                backgroundColor: Colors.green.shade100,
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (suggestedRecipes.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Receitas Sugeridas:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            for (Recipe recipe in suggestedRecipes)
                              ListTile(
                                leading: const Icon(Icons.restaurant, color: Colors.orange),
                                title: Text(recipe.name),
                                subtitle: Text('${recipe.prepTime} min • ${recipe.description}'),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () => _showRecipeDetails(recipe),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}