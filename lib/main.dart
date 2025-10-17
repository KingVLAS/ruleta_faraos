// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:confetti/confetti.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() => runApp(const FarosRuletaApp());

class FarosRuletaApp extends StatelessWidget {
  const FarosRuletaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FAROS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme(),
      home: const RuletaScreen(),
    );
  }
}

/// THEME
class AppTheme {
  static const Color primary = Color(0xFF0B63B6);
  static const Color primaryDark = Color(0xFF084A88);
  static const Color secondary = Color(0xFF23B5D3);
  static const Color tertiary = Color(0xFFF5A524);
  static const Color success = Color(0xFF16A34A);
  static const Color danger = Color(0xFFD32F2F);
  static const Color surfaceSoft = Color(0xFFF2F6FB);

  static const List<Color> wheelColors = <Color>[
    Color(0xFF0B63B6),
    Color(0xFF23B5D3),
    Color(0xFFF5A524),
    Color(0xFF3DDC97),
    Color(0xFF8E6CFF),
    Color(0xFFFE7F88),
    Color(0xFF4DD0E1),
    Color(0xFF7CB342),
  ];

  static ThemeData theme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      textTheme: const TextTheme().apply(
        bodyColor: Color(0xFF0F172A),
        displayColor: Color(0xFF0F172A),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        titleTextStyle: TextStyle(fontSize: 18, letterSpacing: .2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

/// SCREEN (3 PASOS: 0=SEGUIR RED, 1=FORM, 2=RULETA)
class RuletaScreen extends StatefulWidget {
  const RuletaScreen({super.key});
  @override
  State<RuletaScreen> createState() => _RuletaScreenState();
}

class _RuletaScreenState extends State<RuletaScreen>
    with SingleTickerProviderStateMixin {
  // Pasos
  int _step = 0; // 0 Seguir red, 1 Formulario, 2 Ruleta

  // Formulario
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _empresaCtrl = TextEditingController();

  // Premios
  final List<String> premios = const [
    'Botella FAROS',
    'Pelota Antistress',
    'Llavero destapador',
    'Lápiz Corporativo',
    '1 oportunidad más',
    'Sigue participando',
    'Sigue participando',
  ];
  List<int> probs = [15, 15, 15, 15, 10, 15, 15];
  final List<Lead> leads = [];

  // Ruleta
  final _random = Random();
  final _selectedCtrl = StreamController<int>.broadcast(); // multi-listener
  int? _selectedIndex;
  bool _girando = false;

  // Fondo + confetti
  late final AnimationController _bgController;
  late final Animation<double> _bgAnim;
  late final ConfettiController _confetti;

  // Gate (seguimiento red)
  bool _confirmSeguido = false;

  // Config avanzada (oculta por defecto)
  bool _mostrarConfig = false;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _bgAnim = CurvedAnimation(parent: _bgController, curve: Curves.easeInOut);
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _bgController.dispose();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _correoCtrl.dispose();
    _empresaCtrl.dispose();
    _selectedCtrl.close();
    _confetti.dispose();
    super.dispose();
  }

  int _sumaProbs() => probs.fold(0, (a, b) => a + b);

  int _seleccionPonderada(List<int> pesos) {
    final total = pesos.fold(0, (a, b) => a + b);
    if (total <= 0) return 0;
    final r = _random.nextInt(total);
    int acum = 0;
    for (int i = 0; i < pesos.length; i++) {
      acum += pesos[i];
      if (r < acum) return i;
    }
    return pesos.length - 1;
  }

  Future<void> _exportarCSV() async {
    if (leads.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay leads para exportar')),
        );
      }
      return;
    }

    const sep = ';';
    const encabezados = [
      'timestamp',
      'nombre',
      'apellido',
      'correo_corporativo',
      'empresa',
      'premio_obtenido',
    ];
    final filas = leads.map((l) {
      return [
            l.timestamp.toIso8601String(),
            l.nombre,
            l.apellido,
            l.correo,
            l.empresa,
            l.premio,
          ]
          .map((v) {
            final s = v.replaceAll('"', '""');
            return '"$s"';
          })
          .join(sep);
    }).toList();

    final csv = StringBuffer()
      ..writeln(encabezados.join(sep))
      ..writeAll(filas, '\n');

    final bytes = Uint8List.fromList(utf8.encode(csv.toString()));

    final location = await getSaveLocation(
      suggestedName: 'leads_faros.csv',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    if (location == null) return;

    final file = XFile.fromData(
      bytes,
      name: 'leads_faros.csv',
      mimeType: 'text/csv',
    );
    await file.saveTo(location.path);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV guardado en: ${location.path}')),
      );
    }
  }

  void _resetFormulario() {
    _nombreCtrl.clear();
    _apellidoCtrl.clear();
    _correoCtrl.clear();
    _empresaCtrl.clear();
    setState(() => _selectedIndex = null);
  }

  Future<void> _onEnviarYJugar() async {
    if (_girando) return;
    if (!_formKey.currentState!.validate()) return;
    if (_sumaProbs() != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajusta las probabilidades para sumar 100%.'),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    final elegido = _seleccionPonderada(probs);

    leads.add(
      Lead(
        nombre: _nombreCtrl.text.trim(),
        apellido: _apellidoCtrl.text.trim(),
        correo: _correoCtrl.text.trim(),
        empresa: _empresaCtrl.text.trim(),
        premio: premios[elegido],
        timestamp: DateTime.now(),
      ),
    );

    setState(() {
      _girando = true;
      _selectedIndex = elegido;
      _step = 2; // RUEDA full screen
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectedCtrl.add(elegido);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFullWheel = _step == 2;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo suave
          AnimatedBuilder(
            animation: _bgAnim,
            builder: (context, _) {
              final t = _bgAnim.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        AppTheme.primaryDark,
                        AppTheme.secondary,
                        t,
                      )!.withValues(alpha: .10),
                      Color.lerp(
                        AppTheme.secondary,
                        Colors.white,
                        t,
                      )!.withValues(alpha: .08),
                      Colors.white,
                    ],
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
                if (!isFullWheel) _topBar(),
                if (!isFullWheel) const SizedBox(height: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _buildStep(_step),
                  ),
                ),
              ],
            ),
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 36,
              emissionFrequency: 0.0,
              maxBlastForce: 22,
              minBlastForce: 9,
              gravity: 0.16,
              colors: const [
                AppTheme.secondary,
                AppTheme.tertiary,
                AppTheme.success,
                AppTheme.primary,
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _step == 2 ? null : const _ApasepFooter(),
    );
  }

  /// TOP BAR
  Widget _topBar() {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final logoSize = isWide ? 120.0 : 92.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: isWide ? 96 : 88,
        child: Row(
          children: [
            // IZQ: FAROS
            SizedBox(
              width: isWide ? 220 : 160,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  height: logoSize,
                  child: Image.asset(
                    'assets/logo_faros.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // CENTRO: pasos
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: _StepChips(
                  step: _step,
                  onTap: (i) {
                    if (i <= _step) setState(() => _step = i);
                  },
                ),
              ),
            ),
            // DER: contador + acciones
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: LayoutBuilder(
                  builder: (context, b) {
                    final tight = b.maxWidth < 320;
                    return Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _ParticipantsCounter(count: leads.length),
                        Tooltip(
                          message: _mostrarConfig
                              ? 'Ocultar configuración'
                              : 'Mostrar configuración',
                          child: IconButton(
                            onPressed: () => setState(
                              () => _mostrarConfig = !_mostrarConfig,
                            ),
                            icon: Icon(
                              _mostrarConfig ? Icons.tune : Icons.tune_outlined,
                            ),
                          ),
                        ),
                        if (tight)
                          IconButton(
                            tooltip: 'Exportar CSV',
                            onPressed: _exportarCSV,
                            icon: const Icon(Icons.download),
                          )
                        else
                          FilledButton.icon(
                            onPressed: _exportarCSV,
                            icon: const Icon(Icons.download),
                            label: const Text('CSV'),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int step) {
    if (step == 0) {
      return _PasoSeguirRed(
        confirm: _confirmSeguido,
        onConfirmChanged: (v) => setState(() => _confirmSeguido = v),
        onContinuar: _confirmSeguido ? () => setState(() => _step = 1) : null,
      );
    }
    if (step == 1) {
      return _PasoFormulario(
        formKey: _formKey,
        nombreCtrl: _nombreCtrl,
        apellidoCtrl: _apellidoCtrl,
        correoCtrl: _correoCtrl,
        empresaCtrl: _empresaCtrl,
        mostrarConfig: _mostrarConfig,
        probs: probs,
        premios: premios,
        sumaProbs: _sumaProbs(),
        onChangeProb: (i, v) => setState(() => probs[i] = v),
        onEnviarYGirar: _onEnviarYJugar,
      );
    }
    // step 2: RULETA
    return _PasoRuleta(
      selectedStream: _selectedCtrl.stream,
      isSpinning: _girando,
      onStart: () => setState(() => _girando = true),
      onEnd: () {
        if (_selectedIndex == null) return;

        final premio = premios[_selectedIndex!];
        final gano = premio != 'Sigue participando';

        if (gano) {
          HapticFeedback.heavyImpact();
          _confetti.play();
        } else {
          HapticFeedback.selectionClick();
        }

        setState(() => _girando = false);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const _ResultDialog(),
        ).then((_) {
          setState(() => _step = 1);
          _resetFormulario();
        });
      },
    );
  }
}

/// PASO 0: SEGUIR RED – 3 QR cuadradas + ruleta demo
class _PasoSeguirRed extends StatefulWidget {
  final bool confirm;
  final ValueChanged<bool> onConfirmChanged;
  final VoidCallback? onContinuar;

  const _PasoSeguirRed({
    required this.confirm,
    required this.onConfirmChanged,
    required this.onContinuar,
  });

  @override
  State<_PasoSeguirRed> createState() => _PasoSeguirRedState();
}

class _PasoSeguirRedState extends State<_PasoSeguirRed> {
  final _previewCtrl = StreamController<int>.broadcast();
  final _rng = Random();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      _previewCtrl.add(_rng.nextInt(7));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _previewCtrl.add(_rng.nextInt(7));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _previewCtrl.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AnimatedCard(
      child: LayoutBuilder(
        builder: (context, c) {
          return ScrollConfiguration(
            behavior: const _NoGlowBehavior(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: LayoutBuilder(
                  builder: (context, inner) {
                    final wide = inner.maxWidth >= 900;
                    final left = _leftPane();
                    final right = _rightPreview(
                      inner.maxWidth,
                      inner.maxHeight,
                    );

                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 12, child: left),
                          const SizedBox(width: 18),
                          Expanded(flex: 11, child: right),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [left, const SizedBox(height: 18), right],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// IZQUIERDA: 3 QR cuadradas (sin overflow)
  Widget _leftPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'PARTICIPA',
          style: TextStyle(fontSize: 28, letterSpacing: .6),
        ),
        const SizedBox(height: 4),
        Text(
          'Escanea un código y sigue una de nuestras redes.',
          style: TextStyle(color: Colors.black.withValues(alpha: .65)),
        ),
        const SizedBox(height: 14),

        LayoutBuilder(
          builder: (context, cons) {
            const gap = 12.0;
            final totalW = cons.maxWidth;
            double cardW = (totalW - (gap * 2)) / 3;
            cardW = cardW.clamp(160.0, 260.0);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: cardW,
                  child: const AspectRatio(
                    aspectRatio: 1,
                    child: _QRCard(
                      title: 'Instagram · @faroschile',
                      url: 'https://www.instagram.com/faroschile/',
                      color: Colors.pinkAccent,
                      icon: FontAwesomeIcons.instagram,
                      compact: true,
                    ),
                  ),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: cardW,
                  child: const AspectRatio(
                    aspectRatio: 1,
                    child: _QRCard(
                      title: 'Facebook · Faros Asesores Chile',
                      url: 'https://www.facebook.com/FarosAsesoresChile/',
                      color: Colors.blue,
                      icon: FontAwesomeIcons.facebook,
                      compact: true,
                    ),
                  ),
                ),
                const SizedBox(width: gap),
                SizedBox(
                  width: cardW,
                  child: const AspectRatio(
                    aspectRatio: 1,
                    child: _QRCard(
                      title: 'LinkedIn · Faros Chile',
                      url:
                          'https://www.linkedin.com/company/faroschile/?viewAsMember=true',
                      color: Color(0xFF0A66C2),
                      icon: FontAwesomeIcons.linkedin,
                      compact: true,
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 12),
        CheckboxListTile(
          value: widget.confirm,
          onChanged: (v) => widget.onConfirmChanged(v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6),
          title: const Text('Listo, ya seguí una de las redes'),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: widget.onContinuar,
            child: const Text('Continuar'),
          ),
        ),
      ],
    );
  }

  /// DERECHA: Ruleta demo un poco más arriba
  Widget _rightPreview(double maxW, double maxH) {
    final side = (min(maxW, maxH) * 0.84).clamp(320.0, 560.0);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: side,
            height: side,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, AppTheme.surfaceSoft],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                const _GlowHalo(),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Stack(
                    children: [
                      FortuneWheel(
                        animateFirst: false,
                        selected: _previewCtrl.stream,
                        indicators: const [
                          FortuneIndicator(
                            alignment: Alignment.topCenter,
                            child: _PointerIndicator(),
                          ),
                        ],
                        items: _PasoRuleta._wheelItems,
                      ),
                      Center(
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .10),
                                blurRadius: 16,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Image.asset(
                            'assets/logo_faros.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QRCard extends StatelessWidget {
  final String title;
  final String url;
  final Color color;
  final IconData icon;
  final bool compact;

  const _QRCard({
    required this.title,
    required this.url,
    required this.color,
    required this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth; // altura = ancho, gracias al AspectRatio padre
        final qrSize = w * (compact ? 0.60 : 0.66);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: .25), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: compact ? 12.5 : 13.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: AppTheme.surfaceSoft,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(
                      data: url,
                      version: QrVersions.auto,
                      size: qrSize,
                      gapless: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 34,
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    side: BorderSide(color: color.withValues(alpha: .6)),
                    foregroundColor: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Abrir', style: TextStyle(fontSize: 12.5)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// PASO 1: FORMULARIO
class _PasoFormulario extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nombreCtrl;
  final TextEditingController apellidoCtrl;
  final TextEditingController correoCtrl;
  final TextEditingController empresaCtrl;
  final bool mostrarConfig;
  final List<int> probs;
  final List<String> premios;
  final int sumaProbs;
  final void Function(int index, int value) onChangeProb;
  final VoidCallback onEnviarYGirar;

  const _PasoFormulario({
    required this.formKey,
    required this.nombreCtrl,
    required this.apellidoCtrl,
    required this.correoCtrl,
    required this.empresaCtrl,
    required this.mostrarConfig,
    required this.probs,
    required this.premios,
    required this.sumaProbs,
    required this.onChangeProb,
    required this.onEnviarYGirar,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    const _CardHeader(
                      title: 'REGÍSTRATE',
                      subtitle: 'Completa tus datos y gira.',
                      icon: Icons.assignment_ind_outlined,
                    ),
                    const SizedBox(height: 12),
                    AnimatedCrossFade(
                      firstChild: _ConfigProb(
                        probs: probs,
                        premios: premios,
                        sumaProbs: sumaProbs,
                        onChange: onChangeProb,
                      ),
                      secondChild: const SizedBox.shrink(),
                      crossFadeState: mostrarConfig
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 250),
                    ),
                    if (mostrarConfig) const Divider(height: 28),
                    Form(
                      key: formKey,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: nombreCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Nombre',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  textInputAction: TextInputAction.next,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Requerido';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: apellidoCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Apellido',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                  textInputAction: TextInputAction.next,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Requerido';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: correoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Correo corporativo',
                              prefixIcon: Icon(Icons.alternate_email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              final val = v?.trim() ?? '';
                              if (val.isEmpty) {
                                return 'Requerido';
                              }
                              final ok = RegExp(
                                r'^[^@]+@[^@]+\.[^@]+$',
                              ).hasMatch(val);
                              if (!ok) {
                                return 'Correo inválido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: empresaCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Empresa',
                              prefixIcon: Icon(Icons.apartment_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Requerido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: _SpinButton(
                              spinning: false,
                              onPressed: onEnviarYGirar,
                              labelIdle: 'Enviar y Girar',
                              labelSpinning: 'Girando…',
                            ),
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

class _ConfigProb extends StatelessWidget {
  final List<int> probs;
  final List<String> premios;
  final int sumaProbs;
  final void Function(int, int) onChange;

  const _ConfigProb({
    required this.probs,
    required this.premios,
    required this.sumaProbs,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'AJUSTAR PROBABILIDADES (100%)'),
        const SizedBox(height: 6),
        for (int i = 0; i < premios.length; i++) ...[
          Row(
            children: [
              Expanded(child: Text(premios[i])),
              SizedBox(
                width: 72,
                child: Text('${probs[i]}%', textAlign: TextAlign.end),
              ),
            ],
          ),
          Slider(
            value: probs[i].toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '${probs[i]}%',
            onChanged: (v) => onChange(i, v.round()),
          ),
          const SizedBox(height: 2),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Suma: $sumaProbs%',
            style: TextStyle(
              color: sumaProbs == 100 ? AppTheme.success : AppTheme.danger,
            ),
          ),
        ),
      ],
    );
  }
}

/// ===== RULETA – full screen + paneles laterales con logo centrado + QRs + frases con emojis =====
class _PasoRuleta extends StatelessWidget {
  final Stream<int> selectedStream;
  final bool isSpinning;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  const _PasoRuleta({
    required this.selectedStream,
    required this.isSpinning,
    required this.onStart,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final size = _squareSize(w, h);

        // espacio libre a los lados del cuadrado central
        final sideSpace = (w - size) / 2;
        final showPromos = sideSpace >= 300; // mostrar si hay buen margen

        return Stack(
          children: [
            // PROMO APASEP (izquierda)
            if (showPromos)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: min(340, sideSpace - 16),
                    ),
                    child: _PromoPanelAd(
                      logoAsset: 'assets/logo_apasep.png',
                      title: 'APASEP',
                      subtitle: '2025 · Santiago de Chile 🇨🇱',
                      accent: AppTheme.primary,
                      bullets: const [
                        'Automatiza · Optimiza · Avanza 🚀',
                        'Partner tecnológico 🤝',
                        'IA + Apps + Web ⚙️🤖',
                      ],
                      qrs: const [
                        _PromoQr(
                          label: '🌐 apasep.cl',
                          url: 'https://www.apasep.cl',
                          color: AppTheme.primary,
                          icon: FontAwesomeIcons.globe,
                        ),
                        _PromoQr(
                          label: 'IG @apasep.cl',
                          url: 'https://www.instagram.com/apasep',
                          color: Colors.pinkAccent,
                          icon: FontAwesomeIcons.instagram,
                        ),
                      ],
                      footnote:
                          'APASEP 2025 · Santiago de Chile · © Todos los derechos reservados\n'
                          'DISEÑO POR APASEP | IG @apasep.cl',
                    ),
                  ),
                ),
              ),

            // PROMO FAROS (derecha)
            if (showPromos)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: min(340, sideSpace - 16),
                    ),
                    child: _PromoPanelAd(
                      logoAsset: 'assets/logo_faros.png',
                      title: 'FAROS',
                      subtitle: 'Consultoría TI & Logística 📦',
                      accent: AppTheme.tertiary,
                      bullets: const [
                        'Minería ⛏️ · Retail 🛍️',
                        'ERP de clase mundial 🧠',
                        'KPI & Cadena de Abastecimiento 📊',
                        'Picking · Sorting · Despacho 🚚',
                      ],
                      qrs: const [
                        _PromoQr(
                          label: 'IG @faroschile',
                          url: 'https://www.instagram.com/faroschile/',
                          color: Colors.pinkAccent,
                          icon: FontAwesomeIcons.instagram,
                        ),
                        _PromoQr(
                          label: 'LinkedIn',
                          url:
                              'https://www.linkedin.com/company/faroschile/?viewAsMember=true',
                          color: Color(0xFF0A66C2),
                          icon: FontAwesomeIcons.linkedin,
                        ),
                      ],
                      footnote: 'Iluminando decisiones ✨',
                    ),
                  ),
                ),
              ),

            // RULETA central
            Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                scale: isSpinning ? 1.08 : 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, AppTheme.surfaceSoft],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        const _GlowHalo(),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Stack(
                            children: [
                              FortuneWheel(
                                animateFirst: false,
                                selected: selectedStream,
                                duration: const Duration(
                                  seconds: 10,
                                ), // suspenso
                                curve: Curves.easeOutQuart,
                                indicators: const [
                                  FortuneIndicator(
                                    alignment: Alignment.topCenter,
                                    child: _PointerIndicator(),
                                  ),
                                ],
                                onAnimationStart: onStart,
                                onAnimationEnd: onEnd,
                                items: _wheelItems,
                              ),
                              Center(
                                child: Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: .10,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Image.asset(
                                    'assets/logo_faros.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static double _squareSize(double w, double h) {
    final paddingSafe = 8.0;
    return (min(w, h) - paddingSafe).clamp(360.0, 2000.0);
  }

  static List<FortuneItem> get _wheelItems {
    final premios = const [
      'Botella FAROS',
      'Pelota Antistress',
      'Llavero destapador',
      'Lápiz Corporativo',
      '1 oportunidad más',
      'Sigue participando',
      'Sigue participando',
    ];
    return [
      for (int i = 0; i < premios.length; i++)
        FortuneItem(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              premios[i],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          style: FortuneItemStyle(
            borderColor: Colors.white,
            borderWidth: 2,
            color: AppTheme.wheelColors[i % AppTheme.wheelColors.length],
          ),
        ),
    ];
  }
}

/// ===== PROMO PANEL AD (logo centrado + QRs + frases con emojis) =====
class _PromoQr {
  final String label;
  final String url;
  final Color color;
  final IconData icon;
  const _PromoQr({
    required this.label,
    required this.url,
    required this.color,
    required this.icon,
  });
}

class _PromoPanelAd extends StatelessWidget {
  final String logoAsset;
  final String title;
  final String subtitle;
  final Color accent;
  final List<String> bullets;
  final List<_PromoQr> qrs;
  final String? footnote;

  const _PromoPanelAd({
    required this.logoAsset,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.bullets,
    required this.qrs,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: qrs.isNotEmpty
          ? () => launchUrl(
              Uri.parse(qrs.first.url),
              mode: LaunchMode.externalApplication,
            )
          : null,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, AppTheme.surfaceSoft],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: .25), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .10),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo centrado arriba
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 86,
                height: 86,
                child: Image.asset(logoAsset, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: .2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
            const SizedBox(height: 10),

            // QRs de redes/website
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: qrs
                  .map(
                    (q) => _MiniQrTile(
                      label: q.label,
                      url: q.url,
                      color: q.color,
                      icon: q.icon,
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: 10),

            // Frases/beneficios con emojis (cortas)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: bullets
                  .map(
                    (b) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: accent.withValues(alpha: .40),
                        ),
                      ),
                      child: Text(b, style: const TextStyle(fontSize: 12.5)),
                    ),
                  )
                  .toList(),
            ),

            if (footnote != null) ...[
              const SizedBox(height: 10),
              Text(
                footnote!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.black.withValues(alpha: .7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniQrTile extends StatelessWidget {
  final String label;
  final String url;
  final Color color;
  final IconData icon;

  const _MiniQrTile({
    required this.label,
    required this.url,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // QR compacto
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(6),
              child: QrImageView(data: url, version: QrVersions.auto, size: 86),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowHalo extends StatefulWidget {
  const _GlowHalo();
  @override
  State<_GlowHalo> createState() => _GlowHaloState();
}

class _GlowHaloState extends State<_GlowHalo>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final v = (_ctrl.value - .5).abs() * 2; // 0..1..0
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                AppTheme.primary.withValues(alpha: .06 * (1 - v)),
                Colors.transparent,
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// FOOTER APASEP
class _ApasepFooter extends StatelessWidget {
  const _ApasepFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, AppTheme.surfaceSoft],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(top: BorderSide(color: Color(0xFFE5EAF0))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .08),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/logo_apasep.png',
                  fit: BoxFit.contain,
                ),
              ),
              const Text(
                'DISEÑO POR APASEP',
                style: TextStyle(fontSize: 16, letterSpacing: .5),
              ),
              _FooterLink(
                icon: FontAwesomeIcons.globe,
                label: 'WWW.APASEP.CL',
                color: AppTheme.primary,
                onTap: () => launchUrl(
                  Uri.parse('https://www.apasep.cl'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              _FooterLink(
                icon: FontAwesomeIcons.instagram,
                label: '@APASEP',
                color: Colors.pinkAccent,
                onTap: () => launchUrl(
                  Uri.parse('https://www.instagram.com/apasep'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FooterLink({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: .45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13.5)),
          ],
        ),
      ),
    );
  }
}

/// HELPERS
class _ParticipantsCounter extends StatelessWidget {
  final int count;
  const _ParticipantsCounter({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: .4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.people_alt_rounded,
            size: 18,
            color: AppTheme.success,
          ),
          const SizedBox(width: 6),
          const Text('Participantes: ', style: TextStyle(fontSize: 12.5)),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Text(
              '$count',
              key: ValueKey(count),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  const _CardHeader({required this.title, this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 22, letterSpacing: .3),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14.5, letterSpacing: .3),
    );
  }
}

class _AnimatedCard extends StatelessWidget {
  final Widget child;
  const _AnimatedCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .96, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, scale, _) => Transform.scale(
        scale: scale,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .06),
                blurRadius: 20,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Card(child: child),
        ),
      ),
    );
  }
}

class _PointerIndicator extends StatelessWidget {
  const _PointerIndicator();
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.transparent,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppTheme.tertiary,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.expand_more_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

/// ===== RESULT DIALOG (fix: controller en initState para evitar crash) =====
class _ResultDialog extends StatefulWidget {
  const _ResultDialog();

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .9, end: 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.only(top: 18, left: 18, right: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        actionsPadding: const EdgeInsets.only(
          bottom: 12,
          right: 12,
          left: 12,
          top: 6,
        ),
        title: const Center(
          child: Text(
            '¡Gracias por participar!',
            style: TextStyle(fontSize: 22, letterSpacing: .4),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween(begin: .96, end: 1.04).animate(
                CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.white, AppTheme.surfaceSoft],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: .18),
                      blurRadius: 16,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: .20),
                    width: 1.4,
                  ),
                ),
                child: Image.asset(
                  'assets/logo_faros.png',
                  height: 92,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _FarosSocialBar(),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}

/// Quita el glow del overscroll
class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

/// ====== 🔻 FALTANTES QUE PEDÍA EL ANALIZADOR: _StepChips / _SpinButton / _FarosSocialBar 🔻 ======

class _StepChips extends StatelessWidget {
  final int step;
  final ValueChanged<int> onTap;
  const _StepChips({required this.step, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final entries = const [
      (Icons.qr_code_2, 'Seguir red'),
      (Icons.assignment_ind_outlined, 'Datos'),
      (Icons.casino_outlined, 'Girar'),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: List.generate(entries.length, (i) {
        final icon = entries[i].$1;
        final label = entries[i].$2;
        final active = i == step;
        return InkWell(
          onTap: () => onTap(i),
          borderRadius: BorderRadius.circular(100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.primary.withValues(alpha: .10)
                  : Colors.white,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: active
                    ? AppTheme.primary.withValues(alpha: .45)
                    : const Color(0xFFE5EAF0),
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: .12),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active ? AppTheme.primary : Colors.black54,
                ),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _SpinButton extends StatefulWidget {
  final bool spinning;
  final VoidCallback onPressed;
  final String labelIdle;
  final String labelSpinning;

  const _SpinButton({
    required this.spinning,
    required this.onPressed,
    required this.labelIdle,
    required this.labelSpinning,
  });

  @override
  State<_SpinButton> createState() => _SpinButtonState();
}

class _SpinButtonState extends State<_SpinButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  late final Animation<double> _scale = Tween(
    begin: 1.0,
    end: 1.03,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    if (!widget.spinning) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _SpinButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning) {
      _ctrl.stop();
    } else {
      if (!_ctrl.isAnimating) {
        _ctrl.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.spinning ? widget.labelSpinning : widget.labelIdle;
    return ScaleTransition(
      scale: _scale,
      child: FilledButton.icon(
        onPressed: widget.spinning ? null : widget.onPressed,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: widget.spinning
              ? const SizedBox(
                  key: ValueKey('prog'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Icon(Icons.casino),
        ),
        label: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(label, key: ValueKey(label)),
        ),
      ),
    );
  }
}

class _FarosSocialBar extends StatelessWidget {
  const _FarosSocialBar();
  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: const [
        _SocialIconRound(
          iconData: FontAwesomeIcons.instagram,
          label: '@faroschile',
          url: 'https://www.instagram.com/faroschile/',
          color: Colors.pinkAccent,
        ),
        _SocialIconRound(
          iconData: FontAwesomeIcons.facebook,
          label: 'Faros Asesores Chile',
          url: 'https://www.facebook.com/FarosAsesoresChile/',
          color: Colors.blue,
        ),
        _SocialIconRound(
          iconData: FontAwesomeIcons.linkedin,
          label: 'Faros Chile',
          url: 'https://www.linkedin.com/company/faroschile/?viewAsMember=true',
          color: Color(0xFF0A66C2),
        ),
      ],
    );
  }
}

class _SocialIconRound extends StatelessWidget {
  final IconData iconData;
  final String label;
  final String url;
  final Color color;

  const _SocialIconRound({
    required this.iconData,
    required this.label,
    required this.url,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withValues(alpha: .45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13.5)),
          ],
        ),
      ),
    );
  }
}

/// Modelo Lead
class Lead {
  final String nombre;
  final String apellido;
  final String correo;
  final String empresa;
  final String premio;
  final DateTime timestamp;

  Lead({
    required this.nombre,
    required this.apellido,
    required this.correo,
    required this.empresa,
    required this.premio,
    required this.timestamp,
  });
}
