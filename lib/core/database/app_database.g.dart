// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class Clients extends Table with TableInfo<Clients, ClientRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Clients(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0)',
  );
  static const VerificationMeta _fullNameMeta = const VerificationMeta(
    'fullName',
  );
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
    'full_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(full_name)) > 0)',
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _monthlyFeeMinorMeta = const VerificationMeta(
    'monthlyFeeMinor',
  );
  late final GeneratedColumn<int> monthlyFeeMinor = GeneratedColumn<int>(
    'monthly_fee_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (typeof(monthly_fee_minor) = \'integer\' AND monthly_fee_minor >= 0)',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (status IN (\'active\', \'suspended\', \'archived\'))',
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  late final GeneratedColumn<int> archivedAt = GeneratedColumn<int>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _billingStartPeriodMeta =
      const VerificationMeta('billingStartPeriod');
  late final GeneratedColumn<String> billingStartPeriod =
      GeneratedColumn<String>(
        'billing_start_period',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL CHECK (billing_start_period GLOB \'[0-9][0-9][0-9][0-9]-[0-9][0-9]\' AND substr(billing_start_period, 1, 4) >= \'0001\' AND substr(billing_start_period, 6, 2) BETWEEN \'01\' AND \'12\')',
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fullName,
    phone,
    address,
    monthlyFeeMinor,
    status,
    notes,
    createdAt,
    updatedAt,
    archivedAt,
    billingStartPeriod,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clients';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClientRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('full_name')) {
      context.handle(
        _fullNameMeta,
        fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fullNameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('monthly_fee_minor')) {
      context.handle(
        _monthlyFeeMinorMeta,
        monthlyFeeMinor.isAcceptableOrUnknown(
          data['monthly_fee_minor']!,
          _monthlyFeeMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_monthlyFeeMinorMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('billing_start_period')) {
      context.handle(
        _billingStartPeriodMeta,
        billingStartPeriod.isAcceptableOrUnknown(
          data['billing_start_period']!,
          _billingStartPeriodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_billingStartPeriodMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClientRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClientRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fullName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      monthlyFeeMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}monthly_fee_minor'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived_at'],
      ),
      billingStartPeriod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}billing_start_period'],
      )!,
    );
  }

  @override
  Clients createAlias(String alias) {
    return Clients(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'CHECK((status = \'archived\')=(archived_at IS NOT NULL))',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class ClientRecord extends DataClass implements Insertable<ClientRecord> {
  final String id;
  final String fullName;
  final String? phone;
  final String? address;
  final int monthlyFeeMinor;
  final String status;
  final String? notes;
  final int createdAt;
  final int updatedAt;
  final int? archivedAt;

  /// First eligible period of the latest active interval, not an audit instant.
  final String billingStartPeriod;
  const ClientRecord({
    required this.id,
    required this.fullName,
    this.phone,
    this.address,
    required this.monthlyFeeMinor,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    required this.billingStartPeriod,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['full_name'] = Variable<String>(fullName);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    map['monthly_fee_minor'] = Variable<int>(monthlyFeeMinor);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<int>(archivedAt);
    }
    map['billing_start_period'] = Variable<String>(billingStartPeriod);
    return map;
  }

  ClientsCompanion toCompanion(bool nullToAbsent) {
    return ClientsCompanion(
      id: Value(id),
      fullName: Value(fullName),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      monthlyFeeMinor: Value(monthlyFeeMinor),
      status: Value(status),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      billingStartPeriod: Value(billingStartPeriod),
    );
  }

  factory ClientRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClientRecord(
      id: serializer.fromJson<String>(json['id']),
      fullName: serializer.fromJson<String>(json['full_name']),
      phone: serializer.fromJson<String?>(json['phone']),
      address: serializer.fromJson<String?>(json['address']),
      monthlyFeeMinor: serializer.fromJson<int>(json['monthly_fee_minor']),
      status: serializer.fromJson<String>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      archivedAt: serializer.fromJson<int?>(json['archived_at']),
      billingStartPeriod: serializer.fromJson<String>(
        json['billing_start_period'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'full_name': serializer.toJson<String>(fullName),
      'phone': serializer.toJson<String?>(phone),
      'address': serializer.toJson<String?>(address),
      'monthly_fee_minor': serializer.toJson<int>(monthlyFeeMinor),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
      'archived_at': serializer.toJson<int?>(archivedAt),
      'billing_start_period': serializer.toJson<String>(billingStartPeriod),
    };
  }

  ClientRecord copyWith({
    String? id,
    String? fullName,
    Value<String?> phone = const Value.absent(),
    Value<String?> address = const Value.absent(),
    int? monthlyFeeMinor,
    String? status,
    Value<String?> notes = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> archivedAt = const Value.absent(),
    String? billingStartPeriod,
  }) => ClientRecord(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    phone: phone.present ? phone.value : this.phone,
    address: address.present ? address.value : this.address,
    monthlyFeeMinor: monthlyFeeMinor ?? this.monthlyFeeMinor,
    status: status ?? this.status,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    billingStartPeriod: billingStartPeriod ?? this.billingStartPeriod,
  );
  ClientRecord copyWithCompanion(ClientsCompanion data) {
    return ClientRecord(
      id: data.id.present ? data.id.value : this.id,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
      phone: data.phone.present ? data.phone.value : this.phone,
      address: data.address.present ? data.address.value : this.address,
      monthlyFeeMinor: data.monthlyFeeMinor.present
          ? data.monthlyFeeMinor.value
          : this.monthlyFeeMinor,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      billingStartPeriod: data.billingStartPeriod.present
          ? data.billingStartPeriod.value
          : this.billingStartPeriod,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClientRecord(')
          ..write('id: $id, ')
          ..write('fullName: $fullName, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('monthlyFeeMinor: $monthlyFeeMinor, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('billingStartPeriod: $billingStartPeriod')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fullName,
    phone,
    address,
    monthlyFeeMinor,
    status,
    notes,
    createdAt,
    updatedAt,
    archivedAt,
    billingStartPeriod,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClientRecord &&
          other.id == this.id &&
          other.fullName == this.fullName &&
          other.phone == this.phone &&
          other.address == this.address &&
          other.monthlyFeeMinor == this.monthlyFeeMinor &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.archivedAt == this.archivedAt &&
          other.billingStartPeriod == this.billingStartPeriod);
}

class ClientsCompanion extends UpdateCompanion<ClientRecord> {
  final Value<String> id;
  final Value<String> fullName;
  final Value<String?> phone;
  final Value<String?> address;
  final Value<int> monthlyFeeMinor;
  final Value<String> status;
  final Value<String?> notes;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> archivedAt;
  final Value<String> billingStartPeriod;
  final Value<int> rowid;
  const ClientsCompanion({
    this.id = const Value.absent(),
    this.fullName = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.monthlyFeeMinor = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.billingStartPeriod = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClientsCompanion.insert({
    required String id,
    required String fullName,
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    required int monthlyFeeMinor,
    required String status,
    this.notes = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.archivedAt = const Value.absent(),
    required String billingStartPeriod,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fullName = Value(fullName),
       monthlyFeeMinor = Value(monthlyFeeMinor),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       billingStartPeriod = Value(billingStartPeriod);
  static Insertable<ClientRecord> custom({
    Expression<String>? id,
    Expression<String>? fullName,
    Expression<String>? phone,
    Expression<String>? address,
    Expression<int>? monthlyFeeMinor,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? archivedAt,
    Expression<String>? billingStartPeriod,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (monthlyFeeMinor != null) 'monthly_fee_minor': monthlyFeeMinor,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (billingStartPeriod != null)
        'billing_start_period': billingStartPeriod,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClientsCompanion copyWith({
    Value<String>? id,
    Value<String>? fullName,
    Value<String?>? phone,
    Value<String?>? address,
    Value<int>? monthlyFeeMinor,
    Value<String>? status,
    Value<String?>? notes,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? archivedAt,
    Value<String>? billingStartPeriod,
    Value<int>? rowid,
  }) {
    return ClientsCompanion(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      monthlyFeeMinor: monthlyFeeMinor ?? this.monthlyFeeMinor,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      billingStartPeriod: billingStartPeriod ?? this.billingStartPeriod,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (monthlyFeeMinor.present) {
      map['monthly_fee_minor'] = Variable<int>(monthlyFeeMinor.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<int>(archivedAt.value);
    }
    if (billingStartPeriod.present) {
      map['billing_start_period'] = Variable<String>(billingStartPeriod.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientsCompanion(')
          ..write('id: $id, ')
          ..write('fullName: $fullName, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('monthlyFeeMinor: $monthlyFeeMinor, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('billingStartPeriod: $billingStartPeriod, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Devices extends Table with TableInfo<Devices, DeviceRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Devices(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0)',
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES clients(id)ON DELETE RESTRICT',
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (type IN (\'antenna\', \'ont\', \'router\', \'other\'))',
  );
  static const VerificationMeta _macAddressMeta = const VerificationMeta(
    'macAddress',
  );
  late final GeneratedColumn<String> macAddress = GeneratedColumn<String>(
    'mac_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (mac_address IS NULL OR mac_address GLOB \'[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]\')',
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [id, clientId, type, macAddress, notes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('mac_address')) {
      context.handle(
        _macAddressMeta,
        macAddress.isAcceptableOrUnknown(data['mac_address']!, _macAddressMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeviceRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      macAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mac_address'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  Devices createAlias(String alias) {
    return Devices(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DeviceRecord extends DataClass implements Insertable<DeviceRecord> {
  final String id;
  final String clientId;
  final String type;
  final String? macAddress;
  final String? notes;
  const DeviceRecord({
    required this.id,
    required this.clientId,
    required this.type,
    this.macAddress,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['client_id'] = Variable<String>(clientId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || macAddress != null) {
      map['mac_address'] = Variable<String>(macAddress);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  DevicesCompanion toCompanion(bool nullToAbsent) {
    return DevicesCompanion(
      id: Value(id),
      clientId: Value(clientId),
      type: Value(type),
      macAddress: macAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(macAddress),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory DeviceRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceRecord(
      id: serializer.fromJson<String>(json['id']),
      clientId: serializer.fromJson<String>(json['client_id']),
      type: serializer.fromJson<String>(json['type']),
      macAddress: serializer.fromJson<String?>(json['mac_address']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'client_id': serializer.toJson<String>(clientId),
      'type': serializer.toJson<String>(type),
      'mac_address': serializer.toJson<String?>(macAddress),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  DeviceRecord copyWith({
    String? id,
    String? clientId,
    String? type,
    Value<String?> macAddress = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => DeviceRecord(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    type: type ?? this.type,
    macAddress: macAddress.present ? macAddress.value : this.macAddress,
    notes: notes.present ? notes.value : this.notes,
  );
  DeviceRecord copyWithCompanion(DevicesCompanion data) {
    return DeviceRecord(
      id: data.id.present ? data.id.value : this.id,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      type: data.type.present ? data.type.value : this.type,
      macAddress: data.macAddress.present
          ? data.macAddress.value
          : this.macAddress,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceRecord(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('type: $type, ')
          ..write('macAddress: $macAddress, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, clientId, type, macAddress, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceRecord &&
          other.id == this.id &&
          other.clientId == this.clientId &&
          other.type == this.type &&
          other.macAddress == this.macAddress &&
          other.notes == this.notes);
}

class DevicesCompanion extends UpdateCompanion<DeviceRecord> {
  final Value<String> id;
  final Value<String> clientId;
  final Value<String> type;
  final Value<String?> macAddress;
  final Value<String?> notes;
  final Value<int> rowid;
  const DevicesCompanion({
    this.id = const Value.absent(),
    this.clientId = const Value.absent(),
    this.type = const Value.absent(),
    this.macAddress = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DevicesCompanion.insert({
    required String id,
    required String clientId,
    required String type,
    this.macAddress = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientId = Value(clientId),
       type = Value(type);
  static Insertable<DeviceRecord> custom({
    Expression<String>? id,
    Expression<String>? clientId,
    Expression<String>? type,
    Expression<String>? macAddress,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientId != null) 'client_id': clientId,
      if (type != null) 'type': type,
      if (macAddress != null) 'mac_address': macAddress,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DevicesCompanion copyWith({
    Value<String>? id,
    Value<String>? clientId,
    Value<String>? type,
    Value<String?>? macAddress,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return DevicesCompanion(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      type: type ?? this.type,
      macAddress: macAddress ?? this.macAddress,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (macAddress.present) {
      map['mac_address'] = Variable<String>(macAddress.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DevicesCompanion(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('type: $type, ')
          ..write('macAddress: $macAddress, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Charges extends Table with TableInfo<Charges, ChargeRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Charges(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0)',
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES clients(id)ON DELETE RESTRICT',
  );
  static const VerificationMeta _periodKeyMeta = const VerificationMeta(
    'periodKey',
  );
  late final GeneratedColumn<String> periodKey = GeneratedColumn<String>(
    'period_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (period_key GLOB \'[0-9][0-9][0-9][0-9]-[0-9][0-9]\' AND substr(period_key, 1, 4) >= \'0001\' AND substr(period_key, 6, 2) BETWEEN \'01\' AND \'12\')',
  );
  static const VerificationMeta _collectionDateMeta = const VerificationMeta(
    'collectionDate',
  );
  late final GeneratedColumn<String> collectionDate = GeneratedColumn<String>(
    'collection_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (collection_date GLOB \'[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\' AND date(collection_date, \'+0 days\') IS NOT NULL AND date(collection_date, \'+0 days\') = collection_date)',
  );
  static const VerificationMeta _suspensionCandidateDateMeta =
      const VerificationMeta('suspensionCandidateDate');
  late final GeneratedColumn<String>
  suspensionCandidateDate = GeneratedColumn<String>(
    'suspension_candidate_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (suspension_candidate_date = period_key || \'-03\')',
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (typeof(amount_minor) = \'integer\' AND amount_minor >= 0)',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientId,
    periodKey,
    collectionDate,
    suspensionCandidateDate,
    amountMinor,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'charges';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChargeRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('period_key')) {
      context.handle(
        _periodKeyMeta,
        periodKey.isAcceptableOrUnknown(data['period_key']!, _periodKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_periodKeyMeta);
    }
    if (data.containsKey('collection_date')) {
      context.handle(
        _collectionDateMeta,
        collectionDate.isAcceptableOrUnknown(
          data['collection_date']!,
          _collectionDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionDateMeta);
    }
    if (data.containsKey('suspension_candidate_date')) {
      context.handle(
        _suspensionCandidateDateMeta,
        suspensionCandidateDate.isAcceptableOrUnknown(
          data['suspension_candidate_date']!,
          _suspensionCandidateDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_suspensionCandidateDateMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {clientId, periodKey},
  ];
  @override
  ChargeRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChargeRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      periodKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_key'],
      )!,
      collectionDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_date'],
      )!,
      suspensionCandidateDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suspension_candidate_date'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  Charges createAlias(String alias) {
    return Charges(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['UNIQUE(client_id, period_key)'];
  @override
  bool get dontWriteConstraints => true;
}

class ChargeRecord extends DataClass implements Insertable<ChargeRecord> {
  final String id;
  final String clientId;
  final String periodKey;
  final String collectionDate;
  final String suspensionCandidateDate;
  final int amountMinor;
  final int createdAt;
  const ChargeRecord({
    required this.id,
    required this.clientId,
    required this.periodKey,
    required this.collectionDate,
    required this.suspensionCandidateDate,
    required this.amountMinor,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['client_id'] = Variable<String>(clientId);
    map['period_key'] = Variable<String>(periodKey);
    map['collection_date'] = Variable<String>(collectionDate);
    map['suspension_candidate_date'] = Variable<String>(
      suspensionCandidateDate,
    );
    map['amount_minor'] = Variable<int>(amountMinor);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ChargesCompanion toCompanion(bool nullToAbsent) {
    return ChargesCompanion(
      id: Value(id),
      clientId: Value(clientId),
      periodKey: Value(periodKey),
      collectionDate: Value(collectionDate),
      suspensionCandidateDate: Value(suspensionCandidateDate),
      amountMinor: Value(amountMinor),
      createdAt: Value(createdAt),
    );
  }

  factory ChargeRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChargeRecord(
      id: serializer.fromJson<String>(json['id']),
      clientId: serializer.fromJson<String>(json['client_id']),
      periodKey: serializer.fromJson<String>(json['period_key']),
      collectionDate: serializer.fromJson<String>(json['collection_date']),
      suspensionCandidateDate: serializer.fromJson<String>(
        json['suspension_candidate_date'],
      ),
      amountMinor: serializer.fromJson<int>(json['amount_minor']),
      createdAt: serializer.fromJson<int>(json['created_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'client_id': serializer.toJson<String>(clientId),
      'period_key': serializer.toJson<String>(periodKey),
      'collection_date': serializer.toJson<String>(collectionDate),
      'suspension_candidate_date': serializer.toJson<String>(
        suspensionCandidateDate,
      ),
      'amount_minor': serializer.toJson<int>(amountMinor),
      'created_at': serializer.toJson<int>(createdAt),
    };
  }

  ChargeRecord copyWith({
    String? id,
    String? clientId,
    String? periodKey,
    String? collectionDate,
    String? suspensionCandidateDate,
    int? amountMinor,
    int? createdAt,
  }) => ChargeRecord(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    periodKey: periodKey ?? this.periodKey,
    collectionDate: collectionDate ?? this.collectionDate,
    suspensionCandidateDate:
        suspensionCandidateDate ?? this.suspensionCandidateDate,
    amountMinor: amountMinor ?? this.amountMinor,
    createdAt: createdAt ?? this.createdAt,
  );
  ChargeRecord copyWithCompanion(ChargesCompanion data) {
    return ChargeRecord(
      id: data.id.present ? data.id.value : this.id,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      periodKey: data.periodKey.present ? data.periodKey.value : this.periodKey,
      collectionDate: data.collectionDate.present
          ? data.collectionDate.value
          : this.collectionDate,
      suspensionCandidateDate: data.suspensionCandidateDate.present
          ? data.suspensionCandidateDate.value
          : this.suspensionCandidateDate,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChargeRecord(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('periodKey: $periodKey, ')
          ..write('collectionDate: $collectionDate, ')
          ..write('suspensionCandidateDate: $suspensionCandidateDate, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientId,
    periodKey,
    collectionDate,
    suspensionCandidateDate,
    amountMinor,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChargeRecord &&
          other.id == this.id &&
          other.clientId == this.clientId &&
          other.periodKey == this.periodKey &&
          other.collectionDate == this.collectionDate &&
          other.suspensionCandidateDate == this.suspensionCandidateDate &&
          other.amountMinor == this.amountMinor &&
          other.createdAt == this.createdAt);
}

class ChargesCompanion extends UpdateCompanion<ChargeRecord> {
  final Value<String> id;
  final Value<String> clientId;
  final Value<String> periodKey;
  final Value<String> collectionDate;
  final Value<String> suspensionCandidateDate;
  final Value<int> amountMinor;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ChargesCompanion({
    this.id = const Value.absent(),
    this.clientId = const Value.absent(),
    this.periodKey = const Value.absent(),
    this.collectionDate = const Value.absent(),
    this.suspensionCandidateDate = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChargesCompanion.insert({
    required String id,
    required String clientId,
    required String periodKey,
    required String collectionDate,
    required String suspensionCandidateDate,
    required int amountMinor,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientId = Value(clientId),
       periodKey = Value(periodKey),
       collectionDate = Value(collectionDate),
       suspensionCandidateDate = Value(suspensionCandidateDate),
       amountMinor = Value(amountMinor),
       createdAt = Value(createdAt);
  static Insertable<ChargeRecord> custom({
    Expression<String>? id,
    Expression<String>? clientId,
    Expression<String>? periodKey,
    Expression<String>? collectionDate,
    Expression<String>? suspensionCandidateDate,
    Expression<int>? amountMinor,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientId != null) 'client_id': clientId,
      if (periodKey != null) 'period_key': periodKey,
      if (collectionDate != null) 'collection_date': collectionDate,
      if (suspensionCandidateDate != null)
        'suspension_candidate_date': suspensionCandidateDate,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChargesCompanion copyWith({
    Value<String>? id,
    Value<String>? clientId,
    Value<String>? periodKey,
    Value<String>? collectionDate,
    Value<String>? suspensionCandidateDate,
    Value<int>? amountMinor,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return ChargesCompanion(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      periodKey: periodKey ?? this.periodKey,
      collectionDate: collectionDate ?? this.collectionDate,
      suspensionCandidateDate:
          suspensionCandidateDate ?? this.suspensionCandidateDate,
      amountMinor: amountMinor ?? this.amountMinor,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (periodKey.present) {
      map['period_key'] = Variable<String>(periodKey.value);
    }
    if (collectionDate.present) {
      map['collection_date'] = Variable<String>(collectionDate.value);
    }
    if (suspensionCandidateDate.present) {
      map['suspension_candidate_date'] = Variable<String>(
        suspensionCandidateDate.value,
      );
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChargesCompanion(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('periodKey: $periodKey, ')
          ..write('collectionDate: $collectionDate, ')
          ..write('suspensionCandidateDate: $suspensionCandidateDate, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Payments extends Table with TableInfo<Payments, PaymentRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Payments(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(trim(id)) > 0)',
  );
  static const VerificationMeta _chargeIdMeta = const VerificationMeta(
    'chargeId',
  );
  late final GeneratedColumn<String> chargeId = GeneratedColumn<String>(
    'charge_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES charges(id)ON DELETE RESTRICT',
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (typeof(amount_minor) = \'integer\' AND amount_minor >= 0)',
  );
  static const VerificationMeta _paidAtMeta = const VerificationMeta('paidAt');
  late final GeneratedColumn<int> paidAt = GeneratedColumn<int>(
    'paid_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _voidedAtMeta = const VerificationMeta(
    'voidedAt',
  );
  late final GeneratedColumn<int> voidedAt = GeneratedColumn<int>(
    'voided_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    chargeId,
    amountMinor,
    paidAt,
    note,
    voidedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<PaymentRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('charge_id')) {
      context.handle(
        _chargeIdMeta,
        chargeId.isAcceptableOrUnknown(data['charge_id']!, _chargeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chargeIdMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('paid_at')) {
      context.handle(
        _paidAtMeta,
        paidAt.isAcceptableOrUnknown(data['paid_at']!, _paidAtMeta),
      );
    } else if (isInserting) {
      context.missing(_paidAtMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('voided_at')) {
      context.handle(
        _voidedAtMeta,
        voidedAt.isAcceptableOrUnknown(data['voided_at']!, _voidedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PaymentRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaymentRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      chargeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}charge_id'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      paidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paid_at'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      voidedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}voided_at'],
      ),
    );
  }

  @override
  Payments createAlias(String alias) {
    return Payments(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class PaymentRecord extends DataClass implements Insertable<PaymentRecord> {
  final String id;
  final String chargeId;
  final int amountMinor;
  final int paidAt;
  final String? note;
  final int? voidedAt;
  const PaymentRecord({
    required this.id,
    required this.chargeId,
    required this.amountMinor,
    required this.paidAt,
    this.note,
    this.voidedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['charge_id'] = Variable<String>(chargeId);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['paid_at'] = Variable<int>(paidAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || voidedAt != null) {
      map['voided_at'] = Variable<int>(voidedAt);
    }
    return map;
  }

  PaymentsCompanion toCompanion(bool nullToAbsent) {
    return PaymentsCompanion(
      id: Value(id),
      chargeId: Value(chargeId),
      amountMinor: Value(amountMinor),
      paidAt: Value(paidAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      voidedAt: voidedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(voidedAt),
    );
  }

  factory PaymentRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaymentRecord(
      id: serializer.fromJson<String>(json['id']),
      chargeId: serializer.fromJson<String>(json['charge_id']),
      amountMinor: serializer.fromJson<int>(json['amount_minor']),
      paidAt: serializer.fromJson<int>(json['paid_at']),
      note: serializer.fromJson<String?>(json['note']),
      voidedAt: serializer.fromJson<int?>(json['voided_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'charge_id': serializer.toJson<String>(chargeId),
      'amount_minor': serializer.toJson<int>(amountMinor),
      'paid_at': serializer.toJson<int>(paidAt),
      'note': serializer.toJson<String?>(note),
      'voided_at': serializer.toJson<int?>(voidedAt),
    };
  }

  PaymentRecord copyWith({
    String? id,
    String? chargeId,
    int? amountMinor,
    int? paidAt,
    Value<String?> note = const Value.absent(),
    Value<int?> voidedAt = const Value.absent(),
  }) => PaymentRecord(
    id: id ?? this.id,
    chargeId: chargeId ?? this.chargeId,
    amountMinor: amountMinor ?? this.amountMinor,
    paidAt: paidAt ?? this.paidAt,
    note: note.present ? note.value : this.note,
    voidedAt: voidedAt.present ? voidedAt.value : this.voidedAt,
  );
  PaymentRecord copyWithCompanion(PaymentsCompanion data) {
    return PaymentRecord(
      id: data.id.present ? data.id.value : this.id,
      chargeId: data.chargeId.present ? data.chargeId.value : this.chargeId,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      paidAt: data.paidAt.present ? data.paidAt.value : this.paidAt,
      note: data.note.present ? data.note.value : this.note,
      voidedAt: data.voidedAt.present ? data.voidedAt.value : this.voidedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaymentRecord(')
          ..write('id: $id, ')
          ..write('chargeId: $chargeId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('paidAt: $paidAt, ')
          ..write('note: $note, ')
          ..write('voidedAt: $voidedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, chargeId, amountMinor, paidAt, note, voidedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaymentRecord &&
          other.id == this.id &&
          other.chargeId == this.chargeId &&
          other.amountMinor == this.amountMinor &&
          other.paidAt == this.paidAt &&
          other.note == this.note &&
          other.voidedAt == this.voidedAt);
}

class PaymentsCompanion extends UpdateCompanion<PaymentRecord> {
  final Value<String> id;
  final Value<String> chargeId;
  final Value<int> amountMinor;
  final Value<int> paidAt;
  final Value<String?> note;
  final Value<int?> voidedAt;
  final Value<int> rowid;
  const PaymentsCompanion({
    this.id = const Value.absent(),
    this.chargeId = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.note = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PaymentsCompanion.insert({
    required String id,
    required String chargeId,
    required int amountMinor,
    required int paidAt,
    this.note = const Value.absent(),
    this.voidedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       chargeId = Value(chargeId),
       amountMinor = Value(amountMinor),
       paidAt = Value(paidAt);
  static Insertable<PaymentRecord> custom({
    Expression<String>? id,
    Expression<String>? chargeId,
    Expression<int>? amountMinor,
    Expression<int>? paidAt,
    Expression<String>? note,
    Expression<int>? voidedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chargeId != null) 'charge_id': chargeId,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (paidAt != null) 'paid_at': paidAt,
      if (note != null) 'note': note,
      if (voidedAt != null) 'voided_at': voidedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PaymentsCompanion copyWith({
    Value<String>? id,
    Value<String>? chargeId,
    Value<int>? amountMinor,
    Value<int>? paidAt,
    Value<String?>? note,
    Value<int?>? voidedAt,
    Value<int>? rowid,
  }) {
    return PaymentsCompanion(
      id: id ?? this.id,
      chargeId: chargeId ?? this.chargeId,
      amountMinor: amountMinor ?? this.amountMinor,
      paidAt: paidAt ?? this.paidAt,
      note: note ?? this.note,
      voidedAt: voidedAt ?? this.voidedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (chargeId.present) {
      map['charge_id'] = Variable<String>(chargeId.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (paidAt.present) {
      map['paid_at'] = Variable<int>(paidAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (voidedAt.present) {
      map['voided_at'] = Variable<int>(voidedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentsCompanion(')
          ..write('id: $id, ')
          ..write('chargeId: $chargeId, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('paidAt: $paidAt, ')
          ..write('note: $note, ')
          ..write('voidedAt: $voidedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class AppSettings extends Table with TableInfo<AppSettings, SettingsRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AppSettings(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (id = 1)',
  );
  static const VerificationMeta _businessNameMeta = const VerificationMeta(
    'businessName',
  );
  late final GeneratedColumn<String> businessName = GeneratedColumn<String>(
    'business_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT \'Mi Red\' CHECK (length(trim(business_name)) > 0)',
    defaultValue: const CustomExpression('\'Mi Red\''),
  );
  static const VerificationMeta _currencyLabelMeta = const VerificationMeta(
    'currencyLabel',
  );
  late final GeneratedColumn<String> currencyLabel = GeneratedColumn<String>(
    'currency_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _defaultCallingCodeMeta =
      const VerificationMeta('defaultCallingCode');
  late final GeneratedColumn<String> defaultCallingCode =
      GeneratedColumn<String>(
        'default_calling_code',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _notificationsEnabledMeta =
      const VerificationMeta('notificationsEnabled');
  late final GeneratedColumn<bool> notificationsEnabled = GeneratedColumn<bool>(
    'notifications_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT FALSE CHECK (notifications_enabled IN (0, 1))',
    defaultValue: const CustomExpression('FALSE'),
  );
  static const VerificationMeta _lastBackupAtMeta = const VerificationMeta(
    'lastBackupAt',
  );
  late final GeneratedColumn<int> lastBackupAt = GeneratedColumn<int>(
    'last_backup_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessName,
    currencyLabel,
    defaultCallingCode,
    notificationsEnabled,
    lastBackupAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('business_name')) {
      context.handle(
        _businessNameMeta,
        businessName.isAcceptableOrUnknown(
          data['business_name']!,
          _businessNameMeta,
        ),
      );
    }
    if (data.containsKey('currency_label')) {
      context.handle(
        _currencyLabelMeta,
        currencyLabel.isAcceptableOrUnknown(
          data['currency_label']!,
          _currencyLabelMeta,
        ),
      );
    }
    if (data.containsKey('default_calling_code')) {
      context.handle(
        _defaultCallingCodeMeta,
        defaultCallingCode.isAcceptableOrUnknown(
          data['default_calling_code']!,
          _defaultCallingCodeMeta,
        ),
      );
    }
    if (data.containsKey('notifications_enabled')) {
      context.handle(
        _notificationsEnabledMeta,
        notificationsEnabled.isAcceptableOrUnknown(
          data['notifications_enabled']!,
          _notificationsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('last_backup_at')) {
      context.handle(
        _lastBackupAtMeta,
        lastBackupAt.isAcceptableOrUnknown(
          data['last_backup_at']!,
          _lastBackupAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingsRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      businessName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_name'],
      )!,
      currencyLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_label'],
      )!,
      defaultCallingCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_calling_code'],
      ),
      notificationsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notifications_enabled'],
      )!,
      lastBackupAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_backup_at'],
      ),
    );
  }

  @override
  AppSettings createAlias(String alias) {
    return AppSettings(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SettingsRecord extends DataClass implements Insertable<SettingsRecord> {
  final int id;
  final String businessName;
  final String currencyLabel;
  final String? defaultCallingCode;
  final bool notificationsEnabled;
  final int? lastBackupAt;
  const SettingsRecord({
    required this.id,
    required this.businessName,
    required this.currencyLabel,
    this.defaultCallingCode,
    required this.notificationsEnabled,
    this.lastBackupAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['business_name'] = Variable<String>(businessName);
    map['currency_label'] = Variable<String>(currencyLabel);
    if (!nullToAbsent || defaultCallingCode != null) {
      map['default_calling_code'] = Variable<String>(defaultCallingCode);
    }
    map['notifications_enabled'] = Variable<bool>(notificationsEnabled);
    if (!nullToAbsent || lastBackupAt != null) {
      map['last_backup_at'] = Variable<int>(lastBackupAt);
    }
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      businessName: Value(businessName),
      currencyLabel: Value(currencyLabel),
      defaultCallingCode: defaultCallingCode == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultCallingCode),
      notificationsEnabled: Value(notificationsEnabled),
      lastBackupAt: lastBackupAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastBackupAt),
    );
  }

  factory SettingsRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsRecord(
      id: serializer.fromJson<int>(json['id']),
      businessName: serializer.fromJson<String>(json['business_name']),
      currencyLabel: serializer.fromJson<String>(json['currency_label']),
      defaultCallingCode: serializer.fromJson<String?>(
        json['default_calling_code'],
      ),
      notificationsEnabled: serializer.fromJson<bool>(
        json['notifications_enabled'],
      ),
      lastBackupAt: serializer.fromJson<int?>(json['last_backup_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'business_name': serializer.toJson<String>(businessName),
      'currency_label': serializer.toJson<String>(currencyLabel),
      'default_calling_code': serializer.toJson<String?>(defaultCallingCode),
      'notifications_enabled': serializer.toJson<bool>(notificationsEnabled),
      'last_backup_at': serializer.toJson<int?>(lastBackupAt),
    };
  }

  SettingsRecord copyWith({
    int? id,
    String? businessName,
    String? currencyLabel,
    Value<String?> defaultCallingCode = const Value.absent(),
    bool? notificationsEnabled,
    Value<int?> lastBackupAt = const Value.absent(),
  }) => SettingsRecord(
    id: id ?? this.id,
    businessName: businessName ?? this.businessName,
    currencyLabel: currencyLabel ?? this.currencyLabel,
    defaultCallingCode: defaultCallingCode.present
        ? defaultCallingCode.value
        : this.defaultCallingCode,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    lastBackupAt: lastBackupAt.present ? lastBackupAt.value : this.lastBackupAt,
  );
  SettingsRecord copyWithCompanion(AppSettingsCompanion data) {
    return SettingsRecord(
      id: data.id.present ? data.id.value : this.id,
      businessName: data.businessName.present
          ? data.businessName.value
          : this.businessName,
      currencyLabel: data.currencyLabel.present
          ? data.currencyLabel.value
          : this.currencyLabel,
      defaultCallingCode: data.defaultCallingCode.present
          ? data.defaultCallingCode.value
          : this.defaultCallingCode,
      notificationsEnabled: data.notificationsEnabled.present
          ? data.notificationsEnabled.value
          : this.notificationsEnabled,
      lastBackupAt: data.lastBackupAt.present
          ? data.lastBackupAt.value
          : this.lastBackupAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRecord(')
          ..write('id: $id, ')
          ..write('businessName: $businessName, ')
          ..write('currencyLabel: $currencyLabel, ')
          ..write('defaultCallingCode: $defaultCallingCode, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('lastBackupAt: $lastBackupAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessName,
    currencyLabel,
    defaultCallingCode,
    notificationsEnabled,
    lastBackupAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRecord &&
          other.id == this.id &&
          other.businessName == this.businessName &&
          other.currencyLabel == this.currencyLabel &&
          other.defaultCallingCode == this.defaultCallingCode &&
          other.notificationsEnabled == this.notificationsEnabled &&
          other.lastBackupAt == this.lastBackupAt);
}

class AppSettingsCompanion extends UpdateCompanion<SettingsRecord> {
  final Value<int> id;
  final Value<String> businessName;
  final Value<String> currencyLabel;
  final Value<String?> defaultCallingCode;
  final Value<bool> notificationsEnabled;
  final Value<int?> lastBackupAt;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.businessName = const Value.absent(),
    this.currencyLabel = const Value.absent(),
    this.defaultCallingCode = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.lastBackupAt = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.businessName = const Value.absent(),
    this.currencyLabel = const Value.absent(),
    this.defaultCallingCode = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.lastBackupAt = const Value.absent(),
  });
  static Insertable<SettingsRecord> custom({
    Expression<int>? id,
    Expression<String>? businessName,
    Expression<String>? currencyLabel,
    Expression<String>? defaultCallingCode,
    Expression<bool>? notificationsEnabled,
    Expression<int>? lastBackupAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessName != null) 'business_name': businessName,
      if (currencyLabel != null) 'currency_label': currencyLabel,
      if (defaultCallingCode != null)
        'default_calling_code': defaultCallingCode,
      if (notificationsEnabled != null)
        'notifications_enabled': notificationsEnabled,
      if (lastBackupAt != null) 'last_backup_at': lastBackupAt,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? businessName,
    Value<String>? currencyLabel,
    Value<String?>? defaultCallingCode,
    Value<bool>? notificationsEnabled,
    Value<int?>? lastBackupAt,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      currencyLabel: currencyLabel ?? this.currencyLabel,
      defaultCallingCode: defaultCallingCode ?? this.defaultCallingCode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (businessName.present) {
      map['business_name'] = Variable<String>(businessName.value);
    }
    if (currencyLabel.present) {
      map['currency_label'] = Variable<String>(currencyLabel.value);
    }
    if (defaultCallingCode.present) {
      map['default_calling_code'] = Variable<String>(defaultCallingCode.value);
    }
    if (notificationsEnabled.present) {
      map['notifications_enabled'] = Variable<bool>(notificationsEnabled.value);
    }
    if (lastBackupAt.present) {
      map['last_backup_at'] = Variable<int>(lastBackupAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('businessName: $businessName, ')
          ..write('currencyLabel: $currencyLabel, ')
          ..write('defaultCallingCode: $defaultCallingCode, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('lastBackupAt: $lastBackupAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final Clients clients = Clients(this);
  late final Index clientsStatus = Index(
    'clients_status',
    'CREATE INDEX clients_status ON clients (status)',
  );
  late final Devices devices = Devices(this);
  late final Index devicesClient = Index(
    'devices_client',
    'CREATE INDEX devices_client ON devices (client_id)',
  );
  late final Index devicesMac = Index(
    'devices_mac',
    'CREATE INDEX devices_mac ON devices (mac_address)',
  );
  late final Charges charges = Charges(this);
  late final Index chargesPeriod = Index(
    'charges_period',
    'CREATE INDEX charges_period ON charges (period_key)',
  );
  late final Index chargesCandidateDate = Index(
    'charges_candidate_date',
    'CREATE INDEX charges_candidate_date ON charges (suspension_candidate_date)',
  );
  late final Payments payments = Payments(this);
  late final Index paymentsCharge = Index(
    'payments_charge',
    'CREATE INDEX payments_charge ON payments (charge_id)',
  );
  late final Index paymentsOneActive = Index(
    'payments_one_active',
    'CREATE UNIQUE INDEX payments_one_active ON payments (charge_id) WHERE voided_at IS NULL',
  );
  late final Trigger paymentsExactAmount = Trigger(
    'CREATE TRIGGER payments_exact_amount BEFORE INSERT ON payments WHEN NEW.voided_at IS NULL AND NOT EXISTS (SELECT 1 FROM charges WHERE id = NEW.charge_id AND amount_minor = NEW.amount_minor) BEGIN SELECT RAISE (ABORT, \'El importe debe coincidir con un cargo existente.\');END',
    'payments_exact_amount',
  );
  late final Trigger paymentsImmutable = Trigger(
    'CREATE TRIGGER payments_immutable BEFORE UPDATE ON payments WHEN NEW.id IS NOT OLD.id OR NEW.charge_id IS NOT OLD.charge_id OR NEW.amount_minor IS NOT OLD.amount_minor OR NEW.paid_at IS NOT OLD.paid_at OR NEW.note IS NOT OLD.note OR OLD.voided_at IS NOT NULL OR NEW.voided_at IS NULL BEGIN SELECT RAISE (ABORT, \'El pago histórico solo puede anularse una vez.\');END',
    'payments_immutable',
  );
  late final Trigger chargesPreservePaidHistory = Trigger(
    'CREATE TRIGGER charges_preserve_paid_history BEFORE UPDATE ON charges WHEN(EXISTS (SELECT 1 FROM payments WHERE charge_id = OLD.id) AND(NEW.id IS NOT OLD.id OR NEW.client_id IS NOT OLD.client_id OR NEW.period_key IS NOT OLD.period_key))OR(NEW.amount_minor IS NOT OLD.amount_minor AND EXISTS (SELECT 1 FROM payments WHERE charge_id = OLD.id AND voided_at IS NULL))BEGIN SELECT RAISE (ABORT, \'El cargo conserva su historial de pagos.\');END',
    'charges_preserve_paid_history',
  );
  late final AppSettings appSettings = AppSettings(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    clients,
    clientsStatus,
    devices,
    devicesClient,
    devicesMac,
    charges,
    chargesPeriod,
    chargesCandidateDate,
    payments,
    paymentsCharge,
    paymentsOneActive,
    paymentsExactAmount,
    paymentsImmutable,
    chargesPreservePaidHistory,
    appSettings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'payments',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'payments',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'charges',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
  ]);
}

typedef $ClientsCreateCompanionBuilder = ClientsCompanion Function({
  required String id,
  required String fullName,
  Value<String?> phone,
  Value<String?> address,
  required int monthlyFeeMinor,
  required String status,
  Value<String?> notes,
  required int createdAt,
  required int updatedAt,
  Value<int?> archivedAt,
  required String billingStartPeriod,
  Value<int> rowid,
});
typedef $ClientsUpdateCompanionBuilder = ClientsCompanion Function({
  Value<String> id,
  Value<String> fullName,
  Value<String?> phone,
  Value<String?> address,
  Value<int> monthlyFeeMinor,
  Value<String> status,
  Value<String?> notes,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> archivedAt,
  Value<String> billingStartPeriod,
  Value<int> rowid,
});

final class $ClientsReferences
    extends BaseReferences<_$AppDatabase, Clients, ClientRecord> {
  $ClientsReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<Devices, List<DeviceRecord>> _devicesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.devices,
    aliasName: 'clients__id__devices__client_id',
  );

  $DevicesProcessedTableManager get devicesRefs {
    final manager = $DevicesTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.clientId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_devicesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<Charges, List<ChargeRecord>> _chargesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.charges,
    aliasName: 'clients__id__charges__client_id',
  );

  $ChargesProcessedTableManager get chargesRefs {
    final manager = $ChargesTableManager(
      $_db,
      $_db.charges,
    ).filter((f) => f.clientId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_chargesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $ClientsFilterComposer extends Composer<_$AppDatabase, Clients> {
  $ClientsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthlyFeeMinor => $composableBuilder(
    column: $table.monthlyFeeMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get billingStartPeriod => $composableBuilder(
    column: $table.billingStartPeriod,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> devicesRefs(
    Expression<bool> Function($DevicesFilterComposer f) f,
  ) {
    final $DevicesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.clientId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DevicesFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> chargesRefs(
    Expression<bool> Function($ChargesFilterComposer f) f,
  ) {
    final $ChargesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.charges,
      getReferencedColumn: (t) => t.clientId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ChargesFilterComposer(
            $db: $db,
            $table: $db.charges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ClientsOrderingComposer extends Composer<_$AppDatabase, Clients> {
  $ClientsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthlyFeeMinor => $composableBuilder(
    column: $table.monthlyFeeMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get billingStartPeriod => $composableBuilder(
    column: $table.billingStartPeriod,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ClientsAnnotationComposer extends Composer<_$AppDatabase, Clients> {
  $ClientsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<int> get monthlyFeeMinor => $composableBuilder(
    column: $table.monthlyFeeMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get billingStartPeriod => $composableBuilder(
    column: $table.billingStartPeriod,
    builder: (column) => column,
  );

  Expression<T> devicesRefs<T extends Object>(
    Expression<T> Function($DevicesAnnotationComposer a) f,
  ) {
    final $DevicesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.clientId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DevicesAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> chargesRefs<T extends Object>(
    Expression<T> Function($ChargesAnnotationComposer a) f,
  ) {
    final $ChargesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.charges,
      getReferencedColumn: (t) => t.clientId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ChargesAnnotationComposer(
            $db: $db,
            $table: $db.charges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ClientsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Clients,
          ClientRecord,
          $ClientsFilterComposer,
          $ClientsOrderingComposer,
          $ClientsAnnotationComposer,
          $ClientsCreateCompanionBuilder,
          $ClientsUpdateCompanionBuilder,
          (ClientRecord, $ClientsReferences),
          ClientRecord,
          PrefetchHooks Function({bool devicesRefs, bool chargesRefs})
        > {
  $ClientsTableManager(_$AppDatabase db, Clients table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ClientsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ClientsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ClientsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> fullName = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<int> monthlyFeeMinor = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> archivedAt = const Value.absent(),
                Value<String> billingStartPeriod = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClientsCompanion(
                id: id,
                fullName: fullName,
                phone: phone,
                address: address,
                monthlyFeeMinor: monthlyFeeMinor,
                status: status,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                billingStartPeriod: billingStartPeriod,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String fullName,
                Value<String?> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                required int monthlyFeeMinor,
                required String status,
                Value<String?> notes = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> archivedAt = const Value.absent(),
                required String billingStartPeriod,
                Value<int> rowid = const Value.absent(),
              }) => ClientsCompanion.insert(
                id: id,
                fullName: fullName,
                phone: phone,
                address: address,
                monthlyFeeMinor: monthlyFeeMinor,
                status: status,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                billingStartPeriod: billingStartPeriod,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Clients, ClientRecord>(table),
                  $ClientsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({devicesRefs = false, chargesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (devicesRefs) db.devices,
                if (chargesRefs) db.charges,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (devicesRefs)
                    await $_getPrefetchedDataByColumns<
                      ClientRecord,
                      Clients,
                      DeviceRecord,
                      Devices
                    >(
                      currentTable: table,
                      referencedTable: $ClientsReferences._devicesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $ClientsReferences(db, table, p0).devicesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'client_id',
                      typedResults: items,
                    ),
                  if (chargesRefs)
                    await $_getPrefetchedDataByColumns<
                      ClientRecord,
                      Clients,
                      ChargeRecord,
                      Charges
                    >(
                      currentTable: table,
                      referencedTable: $ClientsReferences._chargesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $ClientsReferences(db, table, p0).chargesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'client_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $ClientsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Clients,
      ClientRecord,
      $ClientsFilterComposer,
      $ClientsOrderingComposer,
      $ClientsAnnotationComposer,
      $ClientsCreateCompanionBuilder,
      $ClientsUpdateCompanionBuilder,
      (ClientRecord, $ClientsReferences),
      ClientRecord,
      PrefetchHooks Function({bool devicesRefs, bool chargesRefs})
    >;
typedef $DevicesCreateCompanionBuilder = DevicesCompanion Function({
  required String id,
  required String clientId,
  required String type,
  Value<String?> macAddress,
  Value<String?> notes,
  Value<int> rowid,
});
typedef $DevicesUpdateCompanionBuilder = DevicesCompanion Function({
  Value<String> id,
  Value<String> clientId,
  Value<String> type,
  Value<String?> macAddress,
  Value<String?> notes,
  Value<int> rowid,
});

final class $DevicesReferences
    extends BaseReferences<_$AppDatabase, Devices, DeviceRecord> {
  $DevicesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Clients _clientIdTable(_$AppDatabase db) =>
      db.clients.createAlias('devices__client_id__clients__id');

  $ClientsProcessedTableManager get clientId {
    final $_column = $_itemColumn<String>('client_id')!;

    final manager = $ClientsTableManager(
      $_db,
      $_db.clients,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_clientIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $DevicesFilterComposer extends Composer<_$AppDatabase, Devices> {
  $DevicesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get macAddress => $composableBuilder(
    column: $table.macAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $ClientsFilterComposer get clientId {
    final $ClientsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clientId,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ClientsFilterComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DevicesOrderingComposer extends Composer<_$AppDatabase, Devices> {
  $DevicesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get macAddress => $composableBuilder(
    column: $table.macAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $ClientsOrderingComposer get clientId {
    final $ClientsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clientId,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ClientsOrderingComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DevicesAnnotationComposer extends Composer<_$AppDatabase, Devices> {
  $DevicesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get macAddress => $composableBuilder(
    column: $table.macAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $ClientsAnnotationComposer get clientId {
    final $ClientsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clientId,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ClientsAnnotationComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DevicesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Devices,
          DeviceRecord,
          $DevicesFilterComposer,
          $DevicesOrderingComposer,
          $DevicesAnnotationComposer,
          $DevicesCreateCompanionBuilder,
          $DevicesUpdateCompanionBuilder,
          (DeviceRecord, $DevicesReferences),
          DeviceRecord,
          PrefetchHooks Function({bool clientId})
        > {
  $DevicesTableManager(_$AppDatabase db, Devices table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $DevicesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $DevicesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $DevicesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> macAddress = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion(
                id: id,
                clientId: clientId,
                type: type,
                macAddress: macAddress,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String clientId,
                required String type,
                Value<String?> macAddress = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion.insert(
                id: id,
                clientId: clientId,
                type: type,
                macAddress: macAddress,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Devices, DeviceRecord>(table),
                  $DevicesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({clientId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (clientId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.clientId,
                        referencedTable: $DevicesReferences._clientIdTable(db),
                        referencedColumn: $DevicesReferences
                            ._clientIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $DevicesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Devices,
      DeviceRecord,
      $DevicesFilterComposer,
      $DevicesOrderingComposer,
      $DevicesAnnotationComposer,
      $DevicesCreateCompanionBuilder,
      $DevicesUpdateCompanionBuilder,
      (DeviceRecord, $DevicesReferences),
      DeviceRecord,
      PrefetchHooks Function({bool clientId})
    >;
typedef $ChargesCreateCompanionBuilder = ChargesCompanion Function({
  required String id,
  required String clientId,
  required String periodKey,
  required String collectionDate,
  required String suspensionCandidateDate,
  required int amountMinor,
  required int createdAt,
  Value<int> rowid,
});
typedef $ChargesUpdateCompanionBuilder = ChargesCompanion Function({
  Value<String> id,
  Value<String> clientId,
  Value<String> periodKey,
  Value<String> collectionDate,
  Value<String> suspensionCandidateDate,
  Value<int> amountMinor,
  Value<int> createdAt,
  Value<int> rowid,
});

final class $ChargesReferences
    extends BaseReferences<_$AppDatabase, Charges, ChargeRecord> {
  $ChargesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Clients _clientIdTable(_$AppDatabase db) =>
      db.clients.createAlias('charges__client_id__clients__id');

  $ClientsProcessedTableManager get clientId {
    final $_column = $_itemColumn<String>('client_id')!;

    final manager = $ClientsTableManager(
      $_db,
      $_db.clients,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_clientIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<Payments, List<PaymentRecord>> _paymentsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.payments,
    aliasName: 'charges__id__payments__charge_id',
  );

  $PaymentsProcessedTableManager get paymentsRefs {
    final manager = $PaymentsTableManager(
      $_db,
      $_db.payments,
    ).filter((f) => f.chargeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_paymentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $ChargesFilterComposer extends Composer<_$AppDatabase, Charges> {
  $ChargesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionDate => $composableBuilder(
    column: $table.collectionDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suspensionCandidateDate => $composableBuilder(
    column: $table.suspensionCandidateDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $ClientsFilterComposer get clientId {
    final $ClientsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clientId,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ClientsFilterComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> paymentsRefs(
    Expression<bool> Function($PaymentsFilterComposer f) f,
  ) {
    final $PaymentsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.chargeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PaymentsFilterComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ChargesOrderingComposer extends Composer<_$AppDatabase, Charges> {
  $ChargesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionDate => $composableBuilder(
    column: $table.collectionDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suspensionCandidateDate => $composableBuilder(
    column: $table.suspensionCandidateDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $ClientsOrderingComposer get clientId {
    final $ClientsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clientId,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ClientsOrderingComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ChargesAnnotationComposer extends Composer<_$AppDatabase, Charges> {
  $ChargesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get periodKey =>
      $composableBuilder(column: $table.periodKey, builder: (column) => column);

  GeneratedColumn<String> get collectionDate => $composableBuilder(
    column: $table.collectionDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suspensionCandidateDate => $composableBuilder(
    column: $table.suspensionCandidateDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $ClientsAnnotationComposer get clientId {
    final $ClientsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.clientId,
      referencedTable: $db.clients,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ClientsAnnotationComposer(
            $db: $db,
            $table: $db.clients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> paymentsRefs<T extends Object>(
    Expression<T> Function($PaymentsAnnotationComposer a) f,
  ) {
    final $PaymentsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.payments,
      getReferencedColumn: (t) => t.chargeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PaymentsAnnotationComposer(
            $db: $db,
            $table: $db.payments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ChargesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Charges,
          ChargeRecord,
          $ChargesFilterComposer,
          $ChargesOrderingComposer,
          $ChargesAnnotationComposer,
          $ChargesCreateCompanionBuilder,
          $ChargesUpdateCompanionBuilder,
          (ChargeRecord, $ChargesReferences),
          ChargeRecord,
          PrefetchHooks Function({bool clientId, bool paymentsRefs})
        > {
  $ChargesTableManager(_$AppDatabase db, Charges table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ChargesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ChargesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ChargesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> clientId = const Value.absent(),
                Value<String> periodKey = const Value.absent(),
                Value<String> collectionDate = const Value.absent(),
                Value<String> suspensionCandidateDate = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChargesCompanion(
                id: id,
                clientId: clientId,
                periodKey: periodKey,
                collectionDate: collectionDate,
                suspensionCandidateDate: suspensionCandidateDate,
                amountMinor: amountMinor,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String clientId,
                required String periodKey,
                required String collectionDate,
                required String suspensionCandidateDate,
                required int amountMinor,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ChargesCompanion.insert(
                id: id,
                clientId: clientId,
                periodKey: periodKey,
                collectionDate: collectionDate,
                suspensionCandidateDate: suspensionCandidateDate,
                amountMinor: amountMinor,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Charges, ChargeRecord>(table),
                  $ChargesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({clientId = false, paymentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (paymentsRefs) db.payments],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (clientId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.clientId,
                        referencedTable: $ChargesReferences._clientIdTable(db),
                        referencedColumn: $ChargesReferences
                            ._clientIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (paymentsRefs)
                    await $_getPrefetchedDataByColumns<
                      ChargeRecord,
                      Charges,
                      PaymentRecord,
                      Payments
                    >(
                      currentTable: table,
                      referencedTable: $ChargesReferences._paymentsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $ChargesReferences(db, table, p0).paymentsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'charge_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $ChargesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Charges,
      ChargeRecord,
      $ChargesFilterComposer,
      $ChargesOrderingComposer,
      $ChargesAnnotationComposer,
      $ChargesCreateCompanionBuilder,
      $ChargesUpdateCompanionBuilder,
      (ChargeRecord, $ChargesReferences),
      ChargeRecord,
      PrefetchHooks Function({bool clientId, bool paymentsRefs})
    >;
typedef $PaymentsCreateCompanionBuilder = PaymentsCompanion Function({
  required String id,
  required String chargeId,
  required int amountMinor,
  required int paidAt,
  Value<String?> note,
  Value<int?> voidedAt,
  Value<int> rowid,
});
typedef $PaymentsUpdateCompanionBuilder = PaymentsCompanion Function({
  Value<String> id,
  Value<String> chargeId,
  Value<int> amountMinor,
  Value<int> paidAt,
  Value<String?> note,
  Value<int?> voidedAt,
  Value<int> rowid,
});

final class $PaymentsReferences
    extends BaseReferences<_$AppDatabase, Payments, PaymentRecord> {
  $PaymentsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Charges _chargeIdTable(_$AppDatabase db) =>
      db.charges.createAlias('payments__charge_id__charges__id');

  $ChargesProcessedTableManager get chargeId {
    final $_column = $_itemColumn<String>('charge_id')!;

    final manager = $ChargesTableManager(
      $_db,
      $_db.charges,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chargeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $PaymentsFilterComposer extends Composer<_$AppDatabase, Payments> {
  $PaymentsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get voidedAt => $composableBuilder(
    column: $table.voidedAt,
    builder: (column) => ColumnFilters(column),
  );

  $ChargesFilterComposer get chargeId {
    final $ChargesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chargeId,
      referencedTable: $db.charges,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ChargesFilterComposer(
            $db: $db,
            $table: $db.charges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $PaymentsOrderingComposer extends Composer<_$AppDatabase, Payments> {
  $PaymentsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get voidedAt => $composableBuilder(
    column: $table.voidedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $ChargesOrderingComposer get chargeId {
    final $ChargesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chargeId,
      referencedTable: $db.charges,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ChargesOrderingComposer(
            $db: $db,
            $table: $db.charges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $PaymentsAnnotationComposer extends Composer<_$AppDatabase, Payments> {
  $PaymentsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paidAt =>
      $composableBuilder(column: $table.paidAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get voidedAt =>
      $composableBuilder(column: $table.voidedAt, builder: (column) => column);

  $ChargesAnnotationComposer get chargeId {
    final $ChargesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chargeId,
      referencedTable: $db.charges,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ChargesAnnotationComposer(
            $db: $db,
            $table: $db.charges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $PaymentsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Payments,
          PaymentRecord,
          $PaymentsFilterComposer,
          $PaymentsOrderingComposer,
          $PaymentsAnnotationComposer,
          $PaymentsCreateCompanionBuilder,
          $PaymentsUpdateCompanionBuilder,
          (PaymentRecord, $PaymentsReferences),
          PaymentRecord,
          PrefetchHooks Function({bool chargeId})
        > {
  $PaymentsTableManager(_$AppDatabase db, Payments table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PaymentsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PaymentsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PaymentsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> chargeId = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<int> paidAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> voidedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentsCompanion(
                id: id,
                chargeId: chargeId,
                amountMinor: amountMinor,
                paidAt: paidAt,
                note: note,
                voidedAt: voidedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String chargeId,
                required int amountMinor,
                required int paidAt,
                Value<String?> note = const Value.absent(),
                Value<int?> voidedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentsCompanion.insert(
                id: id,
                chargeId: chargeId,
                amountMinor: amountMinor,
                paidAt: paidAt,
                note: note,
                voidedAt: voidedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Payments, PaymentRecord>(table),
                  $PaymentsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({chargeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (chargeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.chargeId,
                        referencedTable: $PaymentsReferences._chargeIdTable(db),
                        referencedColumn: $PaymentsReferences
                            ._chargeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $PaymentsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Payments,
      PaymentRecord,
      $PaymentsFilterComposer,
      $PaymentsOrderingComposer,
      $PaymentsAnnotationComposer,
      $PaymentsCreateCompanionBuilder,
      $PaymentsUpdateCompanionBuilder,
      (PaymentRecord, $PaymentsReferences),
      PaymentRecord,
      PrefetchHooks Function({bool chargeId})
    >;
typedef $AppSettingsCreateCompanionBuilder = AppSettingsCompanion Function({
  Value<int> id,
  Value<String> businessName,
  Value<String> currencyLabel,
  Value<String?> defaultCallingCode,
  Value<bool> notificationsEnabled,
  Value<int?> lastBackupAt,
});
typedef $AppSettingsUpdateCompanionBuilder = AppSettingsCompanion Function({
  Value<int> id,
  Value<String> businessName,
  Value<String> currencyLabel,
  Value<String?> defaultCallingCode,
  Value<bool> notificationsEnabled,
  Value<int?> lastBackupAt,
});

class $AppSettingsFilterComposer extends Composer<_$AppDatabase, AppSettings> {
  $AppSettingsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessName => $composableBuilder(
    column: $table.businessName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyLabel => $composableBuilder(
    column: $table.currencyLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultCallingCode => $composableBuilder(
    column: $table.defaultCallingCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastBackupAt => $composableBuilder(
    column: $table.lastBackupAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $AppSettingsOrderingComposer
    extends Composer<_$AppDatabase, AppSettings> {
  $AppSettingsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessName => $composableBuilder(
    column: $table.businessName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyLabel => $composableBuilder(
    column: $table.currencyLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultCallingCode => $composableBuilder(
    column: $table.defaultCallingCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastBackupAt => $composableBuilder(
    column: $table.lastBackupAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $AppSettingsAnnotationComposer
    extends Composer<_$AppDatabase, AppSettings> {
  $AppSettingsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get businessName => $composableBuilder(
    column: $table.businessName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyLabel => $composableBuilder(
    column: $table.currencyLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultCallingCode => $composableBuilder(
    column: $table.defaultCallingCode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastBackupAt => $composableBuilder(
    column: $table.lastBackupAt,
    builder: (column) => column,
  );
}

class $AppSettingsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          AppSettings,
          SettingsRecord,
          $AppSettingsFilterComposer,
          $AppSettingsOrderingComposer,
          $AppSettingsAnnotationComposer,
          $AppSettingsCreateCompanionBuilder,
          $AppSettingsUpdateCompanionBuilder,
          (
            SettingsRecord,
            BaseReferences<_$AppDatabase, AppSettings, SettingsRecord>,
          ),
          SettingsRecord,
          PrefetchHooks Function()
        > {
  $AppSettingsTableManager(_$AppDatabase db, AppSettings table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AppSettingsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AppSettingsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AppSettingsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> businessName = const Value.absent(),
                Value<String> currencyLabel = const Value.absent(),
                Value<String?> defaultCallingCode = const Value.absent(),
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<int?> lastBackupAt = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                businessName: businessName,
                currencyLabel: currencyLabel,
                defaultCallingCode: defaultCallingCode,
                notificationsEnabled: notificationsEnabled,
                lastBackupAt: lastBackupAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> businessName = const Value.absent(),
                Value<String> currencyLabel = const Value.absent(),
                Value<String?> defaultCallingCode = const Value.absent(),
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<int?> lastBackupAt = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                id: id,
                businessName: businessName,
                currencyLabel: currencyLabel,
                defaultCallingCode: defaultCallingCode,
                notificationsEnabled: notificationsEnabled,
                lastBackupAt: lastBackupAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<AppSettings, SettingsRecord>(table),
                  BaseReferences<_$AppDatabase, AppSettings, SettingsRecord>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $AppSettingsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      AppSettings,
      SettingsRecord,
      $AppSettingsFilterComposer,
      $AppSettingsOrderingComposer,
      $AppSettingsAnnotationComposer,
      $AppSettingsCreateCompanionBuilder,
      $AppSettingsUpdateCompanionBuilder,
      (
        SettingsRecord,
        BaseReferences<_$AppDatabase, AppSettings, SettingsRecord>,
      ),
      SettingsRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $ClientsTableManager get clients => $ClientsTableManager(_db, _db.clients);
  $DevicesTableManager get devices => $DevicesTableManager(_db, _db.devices);
  $ChargesTableManager get charges => $ChargesTableManager(_db, _db.charges);
  $PaymentsTableManager get payments =>
      $PaymentsTableManager(_db, _db.payments);
  $AppSettingsTableManager get appSettings =>
      $AppSettingsTableManager(_db, _db.appSettings);
}
