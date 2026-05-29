import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/theme.dart';
import 'src/screens/pos_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Landscape preferred for tablet POS use-case.
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);
  runApp(const ProviderScope(child: VidoPosApp()));
}

class VidoPosApp extends StatelessWidget {
  const VidoPosApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vido POS',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const StaffLoginGate(),
    );
  }
}

class StaffLoginGate extends StatefulWidget {
  const StaffLoginGate({super.key});

  @override
  State<StaffLoginGate> createState() => _StaffLoginGateState();
}

class _StaffLoginGateState extends State<StaffLoginGate> {
  var _loggedIn = false;
  var _pin = '';
  var _error = '';

  void _press(String value) {
    setState(() {
      _error = '';
      if (value == 'clear') {
        _pin = '';
      } else if (value == 'back') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < 6) {
        _pin += value;
      }

      if (_pin == '1234') {
        _loggedIn = true;
        _pin = '';
      } else if (_pin.length >= 4) {
        _error = 'Invalid passcode';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedIn) {
      return PosScreen(onLogout: () => setState(() => _loggedIn = false));
    }
    return Scaffold(
      backgroundColor: FC.bg,
      body: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.55, -0.7),
                radius: 1.1,
                colors: [
                  FC.primary.withOpacity(0.28),
                  const Color(0xFF1B2028),
                  FC.bg,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -150,
          right: -110,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: FC.primary.withOpacity(0.16),
            ),
          ),
        ),
        Positioned(
          bottom: -120,
          left: -90,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: FC.accent.withOpacity(0.10),
            ),
          ),
        ),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                width: 430,
                padding: const EdgeInsets.fromLTRB(30, 30, 30, 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: Colors.white.withOpacity(0.22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.34),
                      blurRadius: 50,
                      offset: const Offset(0, 24),
                    ),
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 98,
                    height: 98,
                    child: Image.asset('assets/vido-foody-logo.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 22),
                  const Text('Enter Passcode',
                    style: TextStyle(
                      color: FC.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 30,
                      letterSpacing: 0,
                    )),
                  const SizedBox(height: 8),
                  const Text('Staff access',
                    style: TextStyle(color: FC.textMute, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 15,
                      height: 15,
                      margin: const EdgeInsets.symmetric(horizontal: 9),
                      decoration: BoxDecoration(
                        color: i < _pin.length ? FC.primary : Colors.white.withOpacity(0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i < _pin.length ? FC.primary : Colors.white.withOpacity(0.32),
                        ),
                      ),
                    )),
                  ),
                  SizedBox(
                    height: 34,
                    child: Center(child: Text(_error,
                      style: const TextStyle(color: FC.red, fontWeight: FontWeight.w800))),
                  ),
                  GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    shrinkWrap: true,
                    childAspectRatio: 1.2,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final n in ['1','2','3','4','5','6','7','8','9'])
                        _PinButton(label: n, onTap: () => _press(n)),
                      _PinButton(label: 'Clear', onTap: () => _press('clear'), muted: true),
                      _PinButton(label: '0', onTap: () => _press('0')),
                      _PinButton(label: '⌫', onTap: () => _press('back'), muted: true),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Demo PIN: 1234',
                    style: TextStyle(color: FC.textDim, fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _PinButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool muted;
  const _PinButton({required this.label, required this.onTap, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: muted ? Colors.white.withOpacity(0.09) : Colors.white.withOpacity(0.16),
          shape: BoxShape.circle,
          border: Border.all(
            color: muted ? Colors.white.withOpacity(0.16) : Colors.white.withOpacity(0.28),
          ),
        ),
        child: Center(child: Text(label,
          style: TextStyle(
            color: muted ? FC.textMute : FC.text,
            fontWeight: FontWeight.w700,
            fontSize: muted ? 15 : 32,
          ))),
      ),
    );
  }
}
