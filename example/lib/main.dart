import 'package:flutter/material.dart';
import 'package:flutter_inapp_update/flutter_inapp_update.dart';

/// Real-app usage is a single widget at the root:
///
///   InAppUpdateScope(child: MyApp()) // mandatory: every user must update
///
/// This screen adds a mode switch and a status readout so you can watch the
/// flow. On Android, updates only work when the app was installed from Google
/// Play (internal testing track or internal app sharing). On iOS, the app's
/// bundle ID must be live on the App Store with a higher version.
void main() => runApp(const ExampleApp());

const _green = Color(0xFF3C7A5F);

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  bool _mandatory = true;

  @override
  Widget build(BuildContext context) {
    return InAppUpdateScope(
      mandatory: _mandatory,
      child: MaterialApp(
        title: 'In-app update',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _green),
          scaffoldBackgroundColor: const Color(0xFFF6F7F9),
        ),
        home: UpdateScreen(
          mandatory: _mandatory,
          onMandatoryChanged: (value) => setState(() => _mandatory = value),
        ),
      ),
    );
  }
}

class UpdateScreen extends StatelessWidget {
  const UpdateScreen({
    super.key,
    required this.mandatory,
    required this.onMandatoryChanged,
  });

  final bool mandatory;
  final ValueChanged<bool> onMandatoryChanged;

  @override
  Widget build(BuildContext context) {
    final controller = InAppUpdateScope.of(context);
    final info = controller.updateInfo;
    final status = controller.status;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final textTheme = Theme.of(context).textTheme;
    final hint = textTheme.bodyMedium?.copyWith(color: const Color(0xFF5B616B));

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'In-app update',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: [
                    const ButtonSegment(value: true, label: Text('Mandatory')),
                    ButtonSegment(
                      value: false,
                      label: Text(isIOS ? 'Optional' : 'Flexible'),
                    ),
                  ],
                  selected: {mandatory},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => onMandatoryChanged(s.first),
                ),
                const SizedBox(height: 12),
                Text(_modeHint(isIOS), style: hint),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 12,
                      children: [
                        _Row('Status', status.name),
                        _Row(
                          'Availability',
                          info?.updateAvailability.name ?? '—',
                        ),
                        if (isIOS)
                          _Row(
                            'App Store version',
                            info?.availableVersion ?? '—',
                          )
                        else ...[
                          _Row(
                            'Available version code',
                            info == null ? '—' : '${info.availableVersionCode}',
                          ),
                          _Row(
                            'Immediate / flexible allowed',
                            info == null
                                ? '—'
                                : '${info.isImmediateAllowed} / '
                                    '${info.isFlexibleAllowed}',
                          ),
                        ],
                        _Row(
                          'Staleness (days)',
                          '${info?.clientVersionStalenessDays ?? '—'}',
                        ),
                        if (info?.releaseNotes case final notes?)
                          Text(notes, style: hint),
                        if (status == UpdateStatus.downloading)
                          LinearProgressIndicator(
                            value: controller.progress,
                            color: _green,
                            backgroundColor: const Color(0xFFD7E7DF),
                          ),
                        if (controller.error case final error?)
                          Text(
                            error.message,
                            style: const TextStyle(color: Color(0xFFB3261E)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: status == UpdateStatus.checking ||
                          status == UpdateStatus.prompting
                      ? null
                      : controller.checkNow,
                  child: status == UpdateStatus.checking
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Check for update'),
                ),
              ],
            ),
          ),
          if (status == UpdateStatus.downloaded)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Material(
                color: const Color(0xFF2B2D31),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'An update has been downloaded',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      TextButton(
                        onPressed: controller.completeUpdate,
                        child: const Text(
                          'Reload',
                          style: TextStyle(
                            color: Color(0xFF7FD1A6),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _modeHint(bool isIOS) {
    if (isIOS) {
      return mandatory
          ? 'App Store page on every open/resume. Closing it shows it again.'
          : 'App Store page once per open/resume; closing it lets the user continue.';
    }
    return mandatory
        ? 'Full-screen Play update on every open/resume. Backing out shows it again.'
        : 'Downloads in the background; you choose when to restart.';
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF5B616B))),
        ),
        const SizedBox(width: 12),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
