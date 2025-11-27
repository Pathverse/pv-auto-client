import 'package:args/command_runner.dart';
import 'package:pv_auto_client/commands/auto_command.dart';
import 'package:pv_auto_client/commands/download_spec_command.dart';
import 'package:pv_auto_client/commands/setup_command.dart';

void main(List<String> arguments) async {
  final runner = CommandRunner(
    'pv_auto_client',
    'Generate Chopper clients automatically from Postman collections',
  );

  runner.addCommand(AutoCommand());
  runner.addCommand(SetupCommand());
  runner.addCommand(DownloadSpecCommand());

  try {
    await runner.run(arguments);
  } catch (e) {
    print('Error: $e');
  }
}
