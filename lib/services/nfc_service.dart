import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:ndef_record/ndef_record.dart';

/// Thin service around `nfc_manager` for writing NDEF URI records to
/// physical NFC tags.
///
/// Returns `null` on success, or a human-readable error string on failure.
/// The caller is responsible for showing the error in the UI.
class NfcService {
  /// Writes [url] as an NDEF URI record to the next tag the user taps.
  ///
  /// A session is started and stays open until a tag is discovered (or
  /// an error occurs). The returned [Future] completes only after the
  /// write succeeds or fails — callers can `await` it and react to the
  /// result.
  Future<String?> writeProfileUrl(String url) async {
    try {
      final availability = await NfcManager.instance.checkAvailability();
      if (availability != NfcAvailability.enabled) {
        return 'NFC is not available on this device';
      }

      // Because `startSession` returns void and communicates results
      // through the `onDiscovered` callback, we bridge back to the
      // caller with a Completer.
      final completer = Completer<String?>();

      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              await NfcManager.instance.stopSession(
                errorMessageIos: 'Tag is not NDEF compatible',
              );
              if (!completer.isCompleted) {
                completer.complete('Tag is not NDEF compatible');
              }
              return;
            }
            if (!ndef.isWritable) {
              await NfcManager.instance.stopSession(
                errorMessageIos: 'Tag is read-only',
              );
              if (!completer.isCompleted) {
                completer.complete('Tag is read-only');
              }
              return;
            }

            // Build and write an NDEF URI record.
            final record = _createUriRecord(url);
            final message = NdefMessage(records: [record]);
            await ndef.write(message: message);

            await NfcManager.instance.stopSession(
              alertMessageIos: 'Tag written successfully!',
            );
            if (!completer.isCompleted) completer.complete(null);
          } catch (e) {
            await NfcManager.instance.stopSession(
              errorMessageIos: 'Write failed: $e',
            );
            if (!completer.isCompleted) {
              completer.complete('Write failed: $e');
            }
          }
        },
      );

      return await completer.future;
    } catch (e) {
      return 'NFC error: $e';
    }
  }

  /// Cancel any active NFC session. Safe to call even if no session is
  /// running (the underlying plugin silently ignores the call).
  Future<void> stopSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // Swallow — nothing meaningful to do if stopping fails.
    }
  }

  NdefRecord _createUriRecord(String uri) {
    final uriBytes = utf8.encode(uri);
    final payload = Uint8List(uriBytes.length + 1);
    payload[0] = 0x00; // No prefix
    payload.setRange(1, payload.length, uriBytes);

    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x55]), // 'U'
      identifier: Uint8List(0),
      payload: payload,
    );
  }
}
