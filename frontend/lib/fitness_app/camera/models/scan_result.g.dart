// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_result.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanResultAdapter extends TypeAdapter<ScanResult> {
  @override
  final int typeId = 0;

  @override
  ScanResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanResult(
      imagePath: fields[0] as String,
      predictedClass: fields[1] as String,
      confidence: fields[2] as double,
      timestamp: fields[3] as DateTime,
      synced: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ScanResult obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.imagePath)
      ..writeByte(1)
      ..write(obj.predictedClass)
      ..writeByte(2)
      ..write(obj.confidence)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.synced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ScanResultAdapter &&
              runtimeType == other.runtimeType &&
              typeId == other.typeId;
}