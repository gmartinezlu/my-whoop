# BLE Capture Guide

This file is the human-maintained source of truth for the WHOOP 5.0 BLE protocol observations you make from your own device and traffic captures. Do not enter guessed values.

Note: this workspace's top-level `docs/` directory is read-only, so this project guide lives at the repository root.

## Device

- Owned device serial: `5AG0371037`
- Capture source:
- Capture date:
- iOS version:
- Capture tool:

## Services

Record every observed GATT service UUID.

| Service UUID | Evidence Packet / Time | Notes |
|---|---|---|
| TODO | TODO | TODO |

## Characteristics

Record every characteristic UUID, its properties, and the service that owns it.

| Service UUID | Characteristic UUID | Properties | Evidence Packet / Time | Notes |
|---|---|---|---|---|
| TODO | TODO | notify/read/write | TODO | TODO |

## Frame Header

Document the raw frame layout only after confirming it from repeated captures.

| Byte Range | Meaning | Encoding | Notes |
|---|---|---|---|
| TODO | TODO | TODO | TODO |

## CRC

If frames use CRC16-Modbus or another checksum, document:

- Polynomial:
- Initial value:
- Byte order:
- Covered byte range:
- Example frame:
- Expected CRC:

## Records

Document each record type before implementing it in `Protocol/BLEProtocolDecoder.swift`.

### Heart Rate

- Opcode:
- Payload offsets:
- Scale factor:
- Units:
- Example raw frame:
- Expected decoded value:

### R-R Intervals / HRV

- Opcode:
- Payload offsets:
- Scale factor:
- Units:
- Example raw frame:
- Expected decoded value:

### SpO2

- Opcode:
- Payload offsets:
- Scale factor:
- Units:
- Example raw frame:
- Expected decoded value:

### Skin Temperature

- Opcode:
- Payload offsets:
- Scale factor:
- Units:
- Example raw frame:
- Expected decoded value:

### Respiratory Rate

- Opcode:
- Payload offsets:
- Scale factor:
- Units:
- Example raw frame:
- Expected decoded value:

### Accelerometer

- Opcode:
- Payload offsets:
- Axes order:
- Scale factor:
- Units:
- Example raw frame:
- Expected decoded value:

## Implementation Checklist

- Add confirmed service UUIDs to `Protocol/ProtocolConstants.swift`.
- Add confirmed characteristic UUIDs to `Protocol/ProtocolConstants.swift`.
- Add confirmed opcodes and offsets to `Protocol/ProtocolConstants.swift`.
- Implement parsing in `Protocol/BLEProtocolDecoder.swift`.
- Add decoder tests with raw sample frames and expected typed records.
