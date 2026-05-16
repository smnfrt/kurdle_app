import 'package:flutter/material.dart';
import 'package:kurdle_app/domain.dart';
import 'package:kurdle_app/domain.dart' as domain;
import 'package:kurdle_app/helpers/tile_builder.dart';
import 'package:kurdle_app/services/app_locale.dart';

class HowTo extends StatelessWidget {
  final void Function(domain.Dialog dialog, {bool show}) close;

  const HowTo(this.close, this._settings, {super.key});

  final Settings _settings;

  @override
  Widget build(BuildContext context) {
    return Material(
      shadowColor: Colors.black12,
      child: BlockSemantics(
        blocking: true,
        child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
                width: 500,
                height: 840,
                child: Stack(children: [
                  Positioned(
                      top: 40,
                      left: 0,
                      child: SizedBox(
                        width: 500,
                        height: 800,
                        child: Column(children: [
                          Row(
                            children: [
                              const Spacer(),
                              Padding(
                                padding: const EdgeInsets.only(left: 48),
                                child: Text(
                                  L.howToTitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                  onPressed: () => close(domain.Dialog.help, show: false),
                                  child: Semantics(
                                    label: 'tap to close help',
                                    child: const ExcludeSemantics(
                                        excluding: true,
                                        child: Text("X", style: TextStyle(fontSize: 20))),
                                  ))
                            ],
                          ),
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text.rich(
                                    TextSpan(
                                      text: L.howToDaily,
                                      children: [
                                        TextSpan(
                                            text: L.howToIntro,
                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: L.howToIntroSuffix),
                                      ],
                                    ),
                                    textScaler: TextScaler.linear(1.25)),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                            child: Text.rich(TextSpan(text: L.howToRule1)),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                            child: Text.rich(
                                TextSpan(text: L.howToRule2),
                                textScaler: TextScaler.linear(1.25)),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 16),
                            child: Divider(color: Colors.grey.shade800),
                          ),
                          Row(
                            children: [
                              Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text.rich(
                                      TextSpan(
                                          text: L.howToExamples,
                                          style: const TextStyle(fontSize: 18)),
                                      textScaler: TextScaler.linear(1.25))),
                            ],
                          ),
                          // Örnek 1: B doğru yerde
                          Row(
                            children: [
                              Semantics(
                                label: 'Example word BARAN with B as an exact match',
                                child: Container(
                                  padding: const EdgeInsets.only(left: 16, right: 16),
                                  alignment: Alignment.centerLeft,
                                  width: 300,
                                  height: 80,
                                  child: Flex(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    direction: Axis.horizontal,
                                    children: [
                                      Flexible(child: TileBuilder.build(Letter(value: 'B', color: GameColor.correct), _settings)),
                                      Flexible(child: TileBuilder.build(Letter(value: 'A'), _settings)),
                                      Flexible(child: TileBuilder.build(Letter(value: 'R'), _settings)),
                                      Flexible(child: TileBuilder.build(Letter(value: 'A'), _settings)),
                                      Flexible(child: TileBuilder.build(Letter(value: 'N'), _settings)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text.rich(
                                    TextSpan(
                                      text: '${L.howToLetter} ',
                                      children: [
                                        const TextSpan(text: 'B', style: TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: ' ${L.howToCorrect}'),
                                      ],
                                    ),
                                    textScaler: TextScaler.linear(1.25)),
                              ),
                            ],
                          ),
                          // Örnek 2: I yanlış yerde
                          Row(
                            children: [
                              Semantics(
                                label: 'Example word ŞIVAN with I as a partial match',
                                child: Container(
                                  padding: const EdgeInsets.only(left: 16, right: 16),
                                  alignment: Alignment.centerLeft,
                                  width: 300,
                                  height: 80,
                                  child: Flex(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    direction: Axis.horizontal,
                                    children: [
                                      Flexible(child: TileBuilder.build(Letter(value: 'Ş'), _settings)),
                                      Flexible(child: TileBuilder.build(Letter(value: 'I', color: GameColor.present), _settings)),
                                      Flexible(child: TileBuilder.build(Letter(value: 'V'), _settings)),
                                      Flexible(child: TileBuilder.build(Letter(value: 'A'), _settings)),
                                      Flexible(child: TileBuilder.build(Letter(value: 'N'), _settings)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text.rich(
                                    TextSpan(
                                      text: '${L.howToLetter} ',
                                      children: [
                                        const TextSpan(text: 'I', style: TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: ' ${L.howToPresent}'),
                                      ],
                                    ),
                                    textScaler: TextScaler.linear(1.25)),
                              ),
                            ],
                          ),
                          // Örnek 3: X yok
                          Row(
                            children: [
                              Semantics(
                                label: 'Example word NEXŞE with X not matching',
                                child: Container(
                                  padding: const EdgeInsets.only(left: 16, right: 16),
                                  alignment: Alignment.centerLeft,
                                  width: 300,
                                  height: 80,
                                  child: Flex(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    direction: Axis.horizontal,
                                    children: [
                                      Flexible(child: TileBuilder.build(Letter(value: 'N'), _settings)),
                                      Flexible(child: TileBuilder.build(Letter(value: 'E'), _settings)),
                                      Flexible(child: TileBuilder.build(Letter(value: 'X', color: GameColor.absent), _settings)),
                                      Flexible(child: TileBuilder.build(Letter(value: 'Ş'), _settings)),
                                      Flexible(child: TileBuilder.build(Letter(value: 'E'), _settings)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text.rich(
                                    TextSpan(
                                      text: '${L.howToLetter} ',
                                      children: [
                                        const TextSpan(text: 'X', style: TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: ' ${L.howToAbsent}'),
                                      ],
                                    ),
                                    textScaler: TextScaler.linear(1.25)),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 16),
                            child: Divider(color: Colors.grey.shade800),
                          ),
                          Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text.rich(
                                    TextSpan(
                                      text: L.howToDaily,
                                      children: [
                                        const TextSpan(
                                            text: 'KURDLE',
                                            style: TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: L.howToDailySuffix),
                                      ],
                                    ),
                                    textScaler: TextScaler.linear(1.25)),
                              ),
                            ],
                          ),
                        ]),
                      ))
                ]))),
      ),
    );
  }
}
