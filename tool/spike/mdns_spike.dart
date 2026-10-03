// Spike harness for docs/decisions/0002-mdns-provider.md.
//
// This exists because the checklist in that ADR can only be closed by running
// real multicast traffic, and until now there was no way to run it on demand.
// It is a development tool: nothing here ships in the app bundle, and the
// provider API stays inside lib/features/discovery/data.
//
// It deliberately reports what it did NOT check. A green run here is evidence
// for the local-network items only; the Android and second-device items need
// hardware and stay unticked until someone runs them.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:partilha/core/errors/failure.dart';
import 'package:partilha/core/platform/multicast_lock.dart';
import 'package:partilha/core/result/result.dart';
import 'package:partilha/features/discovery/data/local_address_resolver.dart';
import 'package:partilha/features/discovery/data/mdns_discovery_service.dart';
import 'package:partilha/features/discovery/domain/discovered_device.dart';

/// Writes a line to stdout without tripping `avoid_print`, which is a rule about
/// production code and this file is not production code.
void _say(String line) => stdout.writeln(line);

/// Outcome of a single checklist probe.
class _Check {
  _Check(this.id, this.description, {required this.run});

  /// Matches the checkbox text in the ADR so results can be pasted back into it.
  final String id;
  final String description;
  final Future<_Outcome> Function() run;
}

class _Outcome {
  const _Outcome.pass(this.detail) : verdict = 'PASS';
  const _Outcome.fail(this.detail) : verdict = 'FAIL';

  final String verdict;
  final String detail;
}

/// A service under test, announced on this host.
class _Fixture {
  _Fixture({
    required this.deviceId,
    required this.deviceName,
    required this.port,
    this.capabilities = const <String, String>{},
  });

  final String deviceId;
  final String deviceName;
  final int port;
  final Map<String, String> capabilities;
}

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    _usage();
    return;
  }

  switch (arguments.first) {
    case 'selftest':
      await _selftest();
    case 'advertise':
      await _advertise(arguments);
    case 'discover':
      await _discover(arguments);
    default:
      _usage();
  }
}

void _usage() {
  _say('''
mdns spike harness — see docs/decisions/0002-mdns-provider.md

  selftest                        run every locally checkable probe
  advertise --port <p> [--name <n>] [--id <i>]
                                  announce and hold until interrupted
  discover [--timeout <seconds>]   query and print what is found
''');
}

// -----------------------------------------------------------------------------
// Commands
// -----------------------------------------------------------------------------

/// Announces until killed, for use with the external `dns-sd` observer.
Future<void> _advertise(List<String> arguments) async {
  final int? port = _intOption(arguments, '--port');
  if (port == null) {
    _say('--port is required');
    exitCode = 2;
    return;
  }

  final _Fixture fixture = _Fixture(
    deviceId: _stringOption(arguments, '--id') ?? 'spike-advertiser',
    deviceName: _stringOption(arguments, '--name') ?? 'Spike Advertiser',
    port: port,
  );

  final MdnsDiscoveryService service = _service();
  final Result<void, Failure> started = await service.startAdvertising(
    deviceId: fixture.deviceId,
    deviceName: fixture.deviceName,
    port: fixture.port,
    capabilities: fixture.capabilities,
  );

  if (started case Err(:final error)) {
    _say('FAILED to advertise: $error');
    exitCode = 1;
    return;
  }

  _say(
    'advertising "${fixture.deviceName}" (${fixture.deviceId}) on port '
    '${fixture.port}',
  );
  _say('observe independently with:');
  _say('  dns-sd -B ${MdnsDiscoveryService.serviceType} local.');
  _say(
    '  dns-sd -L "${fixture.deviceName}" '
    '${MdnsDiscoveryService.serviceType} local.',
  );
  _say('Ctrl-C to stop and confirm no phantom record remains.');

  // Hold the announcement open. Without this the service stops before any
  // observer has had a chance to see it.
  await Completer<void>().future;
}

/// Queries once and prints the result.
Future<void> _discover(List<String> arguments) async {
  final Duration timeout = Duration(
    seconds: _intOption(arguments, '--timeout') ?? 3,
  );
  final MdnsDiscoveryService service = _service(responseTimeout: timeout);

  final Stopwatch stopwatch = Stopwatch()..start();
  final Result<List<DiscoveredDevice>, Failure> result = await service
      .discover();
  stopwatch.stop();

  switch (result) {
    case Success(:final value):
      _say(
        'found ${value.length} device(s) in ${stopwatch.elapsedMilliseconds}ms',
      );
      for (final DiscoveredDevice device in value) {
        _say(
          '  ${device.deviceName}  id=${device.deviceId}  '
          '${device.address}:${device.port}  '
          'caps=${jsonEncode(device.capabilities)}',
        );
      }
    case Err(:final error):
      _say('discovery failed: $error');
      exitCode = 1;
  }
}

// -----------------------------------------------------------------------------
// Self-test
// -----------------------------------------------------------------------------

Future<void> _selftest() async {
  final _Fixture fixture = _Fixture(
    deviceId: 'spike-selftest',
    deviceName: 'Spike Selftest',
    // Port is arbitrary: nothing connects during the spike. What matters is that
    // the advertised port survives the round trip unchanged.
    port: 42424,
    capabilities: const <String, String>{'file-transfer': '1'},
  );

  _say(
    'running ${_checks(fixture).length} probe(s) on ${Platform.operatingSystem}',
  );
  _say('');

  int passed = 0;
  int failed = 0;
  int inconclusive = 0;

  for (final _Check check in _checks(fixture)) {
    _Outcome outcome;
    try {
      outcome = await check.run();
    } on Object catch (error) {
      // An escaping exception is itself a result worth recording, not a reason to
      // abandon the remaining probes.
      outcome = _Outcome.fail('threw ${error.runtimeType}: $error');
    }

    switch (outcome.verdict) {
      case 'PASS':
        passed++;
      case 'FAIL':
        failed++;
      default:
        inconclusive++;
    }

    _say('[${outcome.verdict.padRight(13)}] ${check.id}  ${check.description}');
    _say('                ${outcome.detail}');
  }

  _say('');
  _say('$passed passed, $failed failed, $inconclusive inconclusive');
  _say('');
  _say('Still unticked — these need hardware this run cannot substitute for:');
  _say('  [ ] Funciona em Android (device real, com MulticastLock)');
  _say('  [ ] Funciona em macOS (device real, ou seja um segundo Mac na rede)');
  _say('  [ ] Sem crash em interface sem multicast / airplane mode');
  _say('');
  _say(
    'Cross-check this run against the OS resolver, which does not share code',
  );
  _say('with mdns_dart:');
  _say('  dns-sd -B ${MdnsDiscoveryService.serviceType} local.');

  if (failed > 0) exitCode = 1;
}

/// The probes, each tied to a line in the ADR checklist.
List<_Check> _checks(_Fixture fixture) => <_Check>[
  _Check(
    'TXT + SRV round trip',
    'announce then discover on this host, and compare every advertised field',
    run: () => _roundTrip(fixture),
  ),
  _Check(
    'IPv4 address is a real local address',
    'the announced address must be one this host can be reached on',
    run: () => _addressIsReachable(fixture),
  ),
  _Check(
    'Announce and discover simultaneously',
    'the queries used to observe an advertisement must not disturb it',
    run: () => _simultaneous(fixture),
  ),
  _Check(
    'Stopping cleans up',
    'no phantom record may remain after stopAdvertising',
    run: () => _stopCleansUp(fixture),
  ),
  _Check(
    'Advertised port survives the round trip',
    'SRV port must arrive unchanged, since the sender connects to it',
    run: () => _portRoundTrip(fixture),
  ),
];

/// Announces, discovers, and compares the record against what was advertised.
Future<_Outcome> _roundTrip(_Fixture fixture) async {
  final MdnsDiscoveryService advertiser = _service();
  final MdnsDiscoveryService seeker = _service(
    responseTimeout: const Duration(seconds: 5),
  );

  final Result<void, Failure> started = await advertiser.startAdvertising(
    deviceId: fixture.deviceId,
    deviceName: fixture.deviceName,
    port: fixture.port,
    capabilities: fixture.capabilities,
  );
  if (started case Err(:final error)) {
    await advertiser.stopAdvertising();
    return _Outcome.fail('could not advertise: $error');
  }

  try {
    // A short settle delay. mDNS is a chatty protocol: announcing immediately
    // after start races the responder's own registration, and a failure here
    // would be indistinguishable from a real defect.
    await Future<void>.delayed(const Duration(seconds: 2));

    final Result<List<DiscoveredDevice>, Failure> found = await seeker
        .discover();
    if (found case Err(:final error)) {
      return _Outcome.fail('query failed: $error');
    }

    final List<DiscoveredDevice> devices = _devicesOrNull(found)!;
    final DiscoveredDevice? match = _matchDevice(devices, fixture);
    if (match == null) {
      return _Outcome.fail(
        'own advertisement not found among ${devices.length} device(s)',
      );
    }

    final List<String> problems = <String>[];
    if (match.deviceId != fixture.deviceId) {
      problems.add('id "${match.deviceId}" != "${fixture.deviceId}"');
    }
    if (match.deviceName != fixture.deviceName) {
      problems.add('name "${match.deviceName}" != "${fixture.deviceName}"');
    }
    for (final MapEntry<String, String> entry in fixture.capabilities.entries) {
      if (match.capabilities[entry.key] != entry.value) {
        problems.add('capability ${entry.key} != ${entry.value}');
      }
    }

    return problems.isEmpty
        ? const _Outcome.pass('all advertised fields arrived intact')
        : _Outcome.fail(problems.join('; '));
  } finally {
    await advertiser.stopAdvertising();
  }
}

/// The announced address must be one this host can actually be reached on.
Future<_Outcome> _addressIsReachable(_Fixture fixture) async {
  final MdnsDiscoveryService advertiser = _service();
  final Result<void, Failure> started = await advertiser.startAdvertising(
    deviceId: fixture.deviceId,
    deviceName: fixture.deviceName,
    port: fixture.port,
    capabilities: fixture.capabilities,
  );
  if (started case Err(:final error)) {
    await advertiser.stopAdvertising();
    return _Outcome.fail('could not advertise: $error');
  }

  try {
    await Future<void>.delayed(const Duration(seconds: 2));
    final Result<List<DiscoveredDevice>, Failure> found = await _service(
      responseTimeout: const Duration(seconds: 5),
    ).discover();
    if (found case Err(:final error)) {
      return _Outcome.fail('query failed: $error');
    }

    final DiscoveredDevice? match = _matchDevice(
      _devicesOrNull(found)!,
      fixture,
    );
    if (match == null) {
      return const _Outcome.fail('own advertisement not found');
    }

    final List<NetworkInterface> interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    final Set<String> localAddresses = interfaces
        .expand((NetworkInterface i) => i.addresses)
        .map((InternetAddress a) => a.address)
        .toSet();

    if (!localAddresses.contains(match.address)) {
      return _Outcome.fail(
        'announced ${match.address}, which is not an address of this host '
        '(${localAddresses.join(', ')})',
      );
    }

    return _Outcome.pass('${match.address} belongs to this host');
  } finally {
    await advertiser.stopAdvertising();
  }
}

/// Repeatedly queries while advertising, and confirms the record survives.
Future<_Outcome> _simultaneous(_Fixture fixture) async {
  final MdnsDiscoveryService advertiser = _service();
  final Result<void, Failure> started = await advertiser.startAdvertising(
    deviceId: fixture.deviceId,
    deviceName: fixture.deviceName,
    port: fixture.port,
    capabilities: fixture.capabilities,
  );
  if (started case Err(:final error)) {
    await advertiser.stopAdvertising();
    return _Outcome.fail('could not advertise: $error');
  }

  try {
    await Future<void>.delayed(const Duration(seconds: 2));
    final MdnsDiscoveryService seeker = _service(
      responseTimeout: const Duration(seconds: 2),
    );

    // Three rounds: an interference bug that only shows up under repeated
    // traffic would pass a single round trip.
    for (int round = 1; round <= 3; round++) {
      final Result<List<DiscoveredDevice>, Failure> found = await seeker
          .discover();
      if (found case Err(:final error)) {
        return _Outcome.fail('round $round query failed: $error');
      }
      if (_matchDevice(_devicesOrNull(found)!, fixture) == null) {
        return _Outcome.fail('advertisement vanished in round $round');
      }
      _say('                round $round ok');
    }

    // Still advertising after being queried: a responder torn down by its own
    // traffic is the failure this is looking for.
    return advertiser.isAdvertising
        ? const _Outcome.pass(
            'record survived 3 query rounds and is still advertising',
          )
        : const _Outcome.fail('stopped advertising under query load');
  } finally {
    await advertiser.stopAdvertising();
  }
}

/// After stopping, the record must disappear rather than linger as a phantom.
Future<_Outcome> _stopCleansUp(_Fixture fixture) async {
  final MdnsDiscoveryService advertiser = _service();
  final Result<void, Failure> started = await advertiser.startAdvertising(
    deviceId: fixture.deviceId,
    deviceName: fixture.deviceName,
    port: fixture.port,
    capabilities: fixture.capabilities,
  );
  if (started case Err(:final error)) {
    await advertiser.stopAdvertising();
    return _Outcome.fail('could not advertise: $error');
  }

  await Future<void>.delayed(const Duration(seconds: 2));
  final Result<void, Failure> stopped = await advertiser.stopAdvertising();
  if (stopped case Err(:final error)) {
    return _Outcome.fail('stop failed: $error');
  }
  if (advertiser.isAdvertising) {
    return const _Outcome.fail('still reports advertising after stop');
  }

  // mDNS caches aggressively, so an immediate re-query can still see the record
  // and that would be a false failure. Wait past a typical cache lifetime.
  _say('                waiting 5s for the record to age out of any cache');
  await Future<void>.delayed(const Duration(seconds: 5));

  final Result<List<DiscoveredDevice>, Failure> found = await _service(
    responseTimeout: const Duration(seconds: 5),
  ).discover();
  if (found case Err(:final error)) {
    return _Outcome.fail('query failed: $error');
  }

  return _matchDevice(_devicesOrNull(found)!, fixture) == null
      ? const _Outcome.pass('record gone after stop')
      : const _Outcome.fail('phantom record still answering after stop');
}

/// The advertised port must arrive unchanged.
Future<_Outcome> _portRoundTrip(_Fixture fixture) async {
  final MdnsDiscoveryService advertiser = _service();
  final Result<void, Failure> started = await advertiser.startAdvertising(
    deviceId: fixture.deviceId,
    deviceName: fixture.deviceName,
    port: fixture.port,
    capabilities: fixture.capabilities,
  );
  if (started case Err(:final error)) {
    await advertiser.stopAdvertising();
    return _Outcome.fail('could not advertise: $error');
  }

  try {
    await Future<void>.delayed(const Duration(seconds: 2));
    final Result<List<DiscoveredDevice>, Failure> found = await _service(
      responseTimeout: const Duration(seconds: 5),
    ).discover();
    if (found case Err(:final error)) {
      return _Outcome.fail('query failed: $error');
    }

    final DiscoveredDevice? match = _matchDevice(
      _devicesOrNull(found)!,
      fixture,
    );
    if (match == null) {
      return const _Outcome.fail('own advertisement not found');
    }

    return match.port == fixture.port
        ? _Outcome.pass('port ${fixture.port} arrived unchanged')
        : _Outcome.fail(
            'port arrived as ${match.port}, expected ${fixture.port}',
          );
  } finally {
    await advertiser.stopAdvertising();
  }
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

MdnsDiscoveryService _service({
  Duration responseTimeout = const Duration(seconds: 3),
}) => MdnsDiscoveryService(
  hostName: Platform.localHostname,
  // Correct for macOS, where nothing drops multicast. On Android this must be
  // the platform lock, which is why the ADR keeps that item unticked until it
  // has run on hardware.
  multicastLock: const UnrestrictedMulticastLock(),
  responseTimeout: responseTimeout,
  addressResolver: const AllNonLoopbackAddresses(),
);

/// The devices from a successful discovery, or `null` if it failed.
///
/// `Result` exposes no value getter of its own, so every call site would
/// otherwise have to repeat the same match.
List<DiscoveredDevice>? _devicesOrNull(
  Result<List<DiscoveredDevice>, Failure> result,
) => switch (result) {
  Success(:final value) => value,
  Err() => null,
};

DiscoveredDevice? _matchDevice(
  List<DiscoveredDevice> devices,
  _Fixture fixture,
) {
  for (final DiscoveredDevice device in devices) {
    if (device.deviceId == fixture.deviceId) return device;
  }
  return null;
}

String? _stringOption(List<String> arguments, String name) {
  final int index = arguments.indexOf(name);
  return index >= 0 && index + 1 < arguments.length
      ? arguments[index + 1]
      : null;
}

int? _intOption(List<String> arguments, String name) =>
    int.tryParse(_stringOption(arguments, name) ?? '');
