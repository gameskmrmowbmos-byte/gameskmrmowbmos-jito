import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/core/language/language_provider.dart';

class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({this.compact = false, super.key});

  // Kept for existing call sites; the switcher is icon-only in every layout.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appLanguageProvider);
    return PopupMenuButton<AppLanguage>(
      tooltip: context.tr('Change language'),
      initialValue: selected,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      popUpAnimationStyle: AnimationStyle.noAnimation,
      child: Container(
        width: 34,
        height: 34,
        margin: EdgeInsets.only(right: compact ? 8 : 0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(7),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.translate, size: 18, color: Color(0xFF064DB5)),
        ),
      ),
      onSelected: (language) {
        final controller = ref.read(appLanguageProvider.notifier);
        // The menu has no exit animation; scheduling this for the next frame
        // lets Flutter remove the popup route before its inherited widgets
        // receive the locale update.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(controller.setLanguage(language));
        });
      },
      itemBuilder: (context) => [
        for (final language in AppLanguage.values)
          PopupMenuItem<AppLanguage>(
            value: language,
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: selected == language
                      ? const Icon(Icons.check,
                          size: 18, color: Color(0xFF064DB5))
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: Text(
                    language.nativeName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  language.shortName,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
