// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $FoldersTable extends Folders with TableInfo<$FoldersTable, Folder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, parentId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Folder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Folder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Folder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_id'],
      ),
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class Folder extends DataClass implements Insertable<Folder> {
  final int id;
  final String name;
  final int? parentId;
  const Folder({required this.id, required this.name, this.parentId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      name: Value(name),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
    );
  }

  factory Folder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Folder(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      parentId: serializer.fromJson<int?>(json['parentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'parentId': serializer.toJson<int?>(parentId),
    };
  }

  Folder copyWith({
    int? id,
    String? name,
    Value<int?> parentId = const Value.absent(),
  }) => Folder(
    id: id ?? this.id,
    name: name ?? this.name,
    parentId: parentId.present ? parentId.value : this.parentId,
  );
  Folder copyWithCompanion(FoldersCompanion data) {
    return Folder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Folder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, parentId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Folder &&
          other.id == this.id &&
          other.name == this.name &&
          other.parentId == this.parentId);
}

class FoldersCompanion extends UpdateCompanion<Folder> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> parentId;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.parentId = const Value.absent(),
  });
  FoldersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.parentId = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Folder> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? parentId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (parentId != null) 'parent_id': parentId,
    });
  }

  FoldersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? parentId,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId')
          ..write(')'))
        .toString();
  }
}

class $CharactersTable extends Characters
    with TableInfo<$CharactersTable, Character> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CharactersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _personalityMeta = const VerificationMeta(
    'personality',
  );
  @override
  late final GeneratedColumn<String> personality = GeneratedColumn<String>(
    'personality',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _scenarioMeta = const VerificationMeta(
    'scenario',
  );
  @override
  late final GeneratedColumn<String> scenario = GeneratedColumn<String>(
    'scenario',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _firstMessageMeta = const VerificationMeta(
    'firstMessage',
  );
  @override
  late final GeneratedColumn<String> firstMessage = GeneratedColumn<String>(
    'first_message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _mesExampleMeta = const VerificationMeta(
    'mesExample',
  );
  @override
  late final GeneratedColumn<String> mesExample = GeneratedColumn<String>(
    'mes_example',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _systemPromptMeta = const VerificationMeta(
    'systemPrompt',
  );
  @override
  late final GeneratedColumn<String> systemPrompt = GeneratedColumn<String>(
    'system_prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _postHistoryInstructionsMeta =
      const VerificationMeta('postHistoryInstructions');
  @override
  late final GeneratedColumn<String> postHistoryInstructions =
      GeneratedColumn<String>(
        'post_history_instructions',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _alternateGreetingsMeta =
      const VerificationMeta('alternateGreetings');
  @override
  late final GeneratedColumn<String> alternateGreetings =
      GeneratedColumn<String>(
        'alternate_greetings',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ttsVoiceMeta = const VerificationMeta(
    'ttsVoice',
  );
  @override
  late final GeneratedColumn<String> ttsVoice = GeneratedColumn<String>(
    'tts_voice',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id)',
    ),
  );
  static const VerificationMeta _lorebookMeta = const VerificationMeta(
    'lorebook',
  );
  @override
  late final GeneratedColumn<String> lorebook = GeneratedColumn<String>(
    'lorebook',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _worldNamesMeta = const VerificationMeta(
    'worldNames',
  );
  @override
  late final GeneratedColumn<String> worldNames = GeneratedColumn<String>(
    'world_names',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    personality,
    scenario,
    firstMessage,
    mesExample,
    systemPrompt,
    postHistoryInstructions,
    alternateGreetings,
    tags,
    imagePath,
    ttsVoice,
    folderId,
    lorebook,
    worldNames,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'characters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Character> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('personality')) {
      context.handle(
        _personalityMeta,
        personality.isAcceptableOrUnknown(
          data['personality']!,
          _personalityMeta,
        ),
      );
    }
    if (data.containsKey('scenario')) {
      context.handle(
        _scenarioMeta,
        scenario.isAcceptableOrUnknown(data['scenario']!, _scenarioMeta),
      );
    }
    if (data.containsKey('first_message')) {
      context.handle(
        _firstMessageMeta,
        firstMessage.isAcceptableOrUnknown(
          data['first_message']!,
          _firstMessageMeta,
        ),
      );
    }
    if (data.containsKey('mes_example')) {
      context.handle(
        _mesExampleMeta,
        mesExample.isAcceptableOrUnknown(data['mes_example']!, _mesExampleMeta),
      );
    }
    if (data.containsKey('system_prompt')) {
      context.handle(
        _systemPromptMeta,
        systemPrompt.isAcceptableOrUnknown(
          data['system_prompt']!,
          _systemPromptMeta,
        ),
      );
    }
    if (data.containsKey('post_history_instructions')) {
      context.handle(
        _postHistoryInstructionsMeta,
        postHistoryInstructions.isAcceptableOrUnknown(
          data['post_history_instructions']!,
          _postHistoryInstructionsMeta,
        ),
      );
    }
    if (data.containsKey('alternate_greetings')) {
      context.handle(
        _alternateGreetingsMeta,
        alternateGreetings.isAcceptableOrUnknown(
          data['alternate_greetings']!,
          _alternateGreetingsMeta,
        ),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('tts_voice')) {
      context.handle(
        _ttsVoiceMeta,
        ttsVoice.isAcceptableOrUnknown(data['tts_voice']!, _ttsVoiceMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('lorebook')) {
      context.handle(
        _lorebookMeta,
        lorebook.isAcceptableOrUnknown(data['lorebook']!, _lorebookMeta),
      );
    }
    if (data.containsKey('world_names')) {
      context.handle(
        _worldNamesMeta,
        worldNames.isAcceptableOrUnknown(data['world_names']!, _worldNamesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Character map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Character(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      personality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}personality'],
      )!,
      scenario: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scenario'],
      )!,
      firstMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_message'],
      )!,
      mesExample: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mes_example'],
      )!,
      systemPrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}system_prompt'],
      )!,
      postHistoryInstructions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}post_history_instructions'],
      )!,
      alternateGreetings: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alternate_greetings'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      ttsVoice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tts_voice'],
      ),
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      ),
      lorebook: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lorebook'],
      ),
      worldNames: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}world_names'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CharactersTable createAlias(String alias) {
    return $CharactersTable(attachedDatabase, alias);
  }
}

class Character extends DataClass implements Insertable<Character> {
  final int id;
  final String name;
  final String description;
  final String personality;
  final String scenario;
  final String firstMessage;
  final String mesExample;
  final String systemPrompt;
  final String postHistoryInstructions;
  final String alternateGreetings;
  final String tags;
  final String? imagePath;
  final String? ttsVoice;
  final int? folderId;
  final String? lorebook;
  final String worldNames;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Character({
    required this.id,
    required this.name,
    required this.description,
    required this.personality,
    required this.scenario,
    required this.firstMessage,
    required this.mesExample,
    required this.systemPrompt,
    required this.postHistoryInstructions,
    required this.alternateGreetings,
    required this.tags,
    this.imagePath,
    this.ttsVoice,
    this.folderId,
    this.lorebook,
    required this.worldNames,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['personality'] = Variable<String>(personality);
    map['scenario'] = Variable<String>(scenario);
    map['first_message'] = Variable<String>(firstMessage);
    map['mes_example'] = Variable<String>(mesExample);
    map['system_prompt'] = Variable<String>(systemPrompt);
    map['post_history_instructions'] = Variable<String>(
      postHistoryInstructions,
    );
    map['alternate_greetings'] = Variable<String>(alternateGreetings);
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    if (!nullToAbsent || ttsVoice != null) {
      map['tts_voice'] = Variable<String>(ttsVoice);
    }
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<int>(folderId);
    }
    if (!nullToAbsent || lorebook != null) {
      map['lorebook'] = Variable<String>(lorebook);
    }
    map['world_names'] = Variable<String>(worldNames);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CharactersCompanion toCompanion(bool nullToAbsent) {
    return CharactersCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      personality: Value(personality),
      scenario: Value(scenario),
      firstMessage: Value(firstMessage),
      mesExample: Value(mesExample),
      systemPrompt: Value(systemPrompt),
      postHistoryInstructions: Value(postHistoryInstructions),
      alternateGreetings: Value(alternateGreetings),
      tags: Value(tags),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      ttsVoice: ttsVoice == null && nullToAbsent
          ? const Value.absent()
          : Value(ttsVoice),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      lorebook: lorebook == null && nullToAbsent
          ? const Value.absent()
          : Value(lorebook),
      worldNames: Value(worldNames),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Character.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Character(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      personality: serializer.fromJson<String>(json['personality']),
      scenario: serializer.fromJson<String>(json['scenario']),
      firstMessage: serializer.fromJson<String>(json['firstMessage']),
      mesExample: serializer.fromJson<String>(json['mesExample']),
      systemPrompt: serializer.fromJson<String>(json['systemPrompt']),
      postHistoryInstructions: serializer.fromJson<String>(
        json['postHistoryInstructions'],
      ),
      alternateGreetings: serializer.fromJson<String>(
        json['alternateGreetings'],
      ),
      tags: serializer.fromJson<String>(json['tags']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      ttsVoice: serializer.fromJson<String?>(json['ttsVoice']),
      folderId: serializer.fromJson<int?>(json['folderId']),
      lorebook: serializer.fromJson<String?>(json['lorebook']),
      worldNames: serializer.fromJson<String>(json['worldNames']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'personality': serializer.toJson<String>(personality),
      'scenario': serializer.toJson<String>(scenario),
      'firstMessage': serializer.toJson<String>(firstMessage),
      'mesExample': serializer.toJson<String>(mesExample),
      'systemPrompt': serializer.toJson<String>(systemPrompt),
      'postHistoryInstructions': serializer.toJson<String>(
        postHistoryInstructions,
      ),
      'alternateGreetings': serializer.toJson<String>(alternateGreetings),
      'tags': serializer.toJson<String>(tags),
      'imagePath': serializer.toJson<String?>(imagePath),
      'ttsVoice': serializer.toJson<String?>(ttsVoice),
      'folderId': serializer.toJson<int?>(folderId),
      'lorebook': serializer.toJson<String?>(lorebook),
      'worldNames': serializer.toJson<String>(worldNames),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Character copyWith({
    int? id,
    String? name,
    String? description,
    String? personality,
    String? scenario,
    String? firstMessage,
    String? mesExample,
    String? systemPrompt,
    String? postHistoryInstructions,
    String? alternateGreetings,
    String? tags,
    Value<String?> imagePath = const Value.absent(),
    Value<String?> ttsVoice = const Value.absent(),
    Value<int?> folderId = const Value.absent(),
    Value<String?> lorebook = const Value.absent(),
    String? worldNames,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Character(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    personality: personality ?? this.personality,
    scenario: scenario ?? this.scenario,
    firstMessage: firstMessage ?? this.firstMessage,
    mesExample: mesExample ?? this.mesExample,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    postHistoryInstructions:
        postHistoryInstructions ?? this.postHistoryInstructions,
    alternateGreetings: alternateGreetings ?? this.alternateGreetings,
    tags: tags ?? this.tags,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    ttsVoice: ttsVoice.present ? ttsVoice.value : this.ttsVoice,
    folderId: folderId.present ? folderId.value : this.folderId,
    lorebook: lorebook.present ? lorebook.value : this.lorebook,
    worldNames: worldNames ?? this.worldNames,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Character copyWithCompanion(CharactersCompanion data) {
    return Character(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      personality: data.personality.present
          ? data.personality.value
          : this.personality,
      scenario: data.scenario.present ? data.scenario.value : this.scenario,
      firstMessage: data.firstMessage.present
          ? data.firstMessage.value
          : this.firstMessage,
      mesExample: data.mesExample.present
          ? data.mesExample.value
          : this.mesExample,
      systemPrompt: data.systemPrompt.present
          ? data.systemPrompt.value
          : this.systemPrompt,
      postHistoryInstructions: data.postHistoryInstructions.present
          ? data.postHistoryInstructions.value
          : this.postHistoryInstructions,
      alternateGreetings: data.alternateGreetings.present
          ? data.alternateGreetings.value
          : this.alternateGreetings,
      tags: data.tags.present ? data.tags.value : this.tags,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      ttsVoice: data.ttsVoice.present ? data.ttsVoice.value : this.ttsVoice,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      lorebook: data.lorebook.present ? data.lorebook.value : this.lorebook,
      worldNames: data.worldNames.present
          ? data.worldNames.value
          : this.worldNames,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Character(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('personality: $personality, ')
          ..write('scenario: $scenario, ')
          ..write('firstMessage: $firstMessage, ')
          ..write('mesExample: $mesExample, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('postHistoryInstructions: $postHistoryInstructions, ')
          ..write('alternateGreetings: $alternateGreetings, ')
          ..write('tags: $tags, ')
          ..write('imagePath: $imagePath, ')
          ..write('ttsVoice: $ttsVoice, ')
          ..write('folderId: $folderId, ')
          ..write('lorebook: $lorebook, ')
          ..write('worldNames: $worldNames, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    personality,
    scenario,
    firstMessage,
    mesExample,
    systemPrompt,
    postHistoryInstructions,
    alternateGreetings,
    tags,
    imagePath,
    ttsVoice,
    folderId,
    lorebook,
    worldNames,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Character &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.personality == this.personality &&
          other.scenario == this.scenario &&
          other.firstMessage == this.firstMessage &&
          other.mesExample == this.mesExample &&
          other.systemPrompt == this.systemPrompt &&
          other.postHistoryInstructions == this.postHistoryInstructions &&
          other.alternateGreetings == this.alternateGreetings &&
          other.tags == this.tags &&
          other.imagePath == this.imagePath &&
          other.ttsVoice == this.ttsVoice &&
          other.folderId == this.folderId &&
          other.lorebook == this.lorebook &&
          other.worldNames == this.worldNames &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CharactersCompanion extends UpdateCompanion<Character> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> description;
  final Value<String> personality;
  final Value<String> scenario;
  final Value<String> firstMessage;
  final Value<String> mesExample;
  final Value<String> systemPrompt;
  final Value<String> postHistoryInstructions;
  final Value<String> alternateGreetings;
  final Value<String> tags;
  final Value<String?> imagePath;
  final Value<String?> ttsVoice;
  final Value<int?> folderId;
  final Value<String?> lorebook;
  final Value<String> worldNames;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const CharactersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.personality = const Value.absent(),
    this.scenario = const Value.absent(),
    this.firstMessage = const Value.absent(),
    this.mesExample = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.postHistoryInstructions = const Value.absent(),
    this.alternateGreetings = const Value.absent(),
    this.tags = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.ttsVoice = const Value.absent(),
    this.folderId = const Value.absent(),
    this.lorebook = const Value.absent(),
    this.worldNames = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  CharactersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.personality = const Value.absent(),
    this.scenario = const Value.absent(),
    this.firstMessage = const Value.absent(),
    this.mesExample = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.postHistoryInstructions = const Value.absent(),
    this.alternateGreetings = const Value.absent(),
    this.tags = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.ttsVoice = const Value.absent(),
    this.folderId = const Value.absent(),
    this.lorebook = const Value.absent(),
    this.worldNames = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Character> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? personality,
    Expression<String>? scenario,
    Expression<String>? firstMessage,
    Expression<String>? mesExample,
    Expression<String>? systemPrompt,
    Expression<String>? postHistoryInstructions,
    Expression<String>? alternateGreetings,
    Expression<String>? tags,
    Expression<String>? imagePath,
    Expression<String>? ttsVoice,
    Expression<int>? folderId,
    Expression<String>? lorebook,
    Expression<String>? worldNames,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (personality != null) 'personality': personality,
      if (scenario != null) 'scenario': scenario,
      if (firstMessage != null) 'first_message': firstMessage,
      if (mesExample != null) 'mes_example': mesExample,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (postHistoryInstructions != null)
        'post_history_instructions': postHistoryInstructions,
      if (alternateGreetings != null) 'alternate_greetings': alternateGreetings,
      if (tags != null) 'tags': tags,
      if (imagePath != null) 'image_path': imagePath,
      if (ttsVoice != null) 'tts_voice': ttsVoice,
      if (folderId != null) 'folder_id': folderId,
      if (lorebook != null) 'lorebook': lorebook,
      if (worldNames != null) 'world_names': worldNames,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  CharactersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? description,
    Value<String>? personality,
    Value<String>? scenario,
    Value<String>? firstMessage,
    Value<String>? mesExample,
    Value<String>? systemPrompt,
    Value<String>? postHistoryInstructions,
    Value<String>? alternateGreetings,
    Value<String>? tags,
    Value<String?>? imagePath,
    Value<String?>? ttsVoice,
    Value<int?>? folderId,
    Value<String?>? lorebook,
    Value<String>? worldNames,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return CharactersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      personality: personality ?? this.personality,
      scenario: scenario ?? this.scenario,
      firstMessage: firstMessage ?? this.firstMessage,
      mesExample: mesExample ?? this.mesExample,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      postHistoryInstructions:
          postHistoryInstructions ?? this.postHistoryInstructions,
      alternateGreetings: alternateGreetings ?? this.alternateGreetings,
      tags: tags ?? this.tags,
      imagePath: imagePath ?? this.imagePath,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      folderId: folderId ?? this.folderId,
      lorebook: lorebook ?? this.lorebook,
      worldNames: worldNames ?? this.worldNames,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (personality.present) {
      map['personality'] = Variable<String>(personality.value);
    }
    if (scenario.present) {
      map['scenario'] = Variable<String>(scenario.value);
    }
    if (firstMessage.present) {
      map['first_message'] = Variable<String>(firstMessage.value);
    }
    if (mesExample.present) {
      map['mes_example'] = Variable<String>(mesExample.value);
    }
    if (systemPrompt.present) {
      map['system_prompt'] = Variable<String>(systemPrompt.value);
    }
    if (postHistoryInstructions.present) {
      map['post_history_instructions'] = Variable<String>(
        postHistoryInstructions.value,
      );
    }
    if (alternateGreetings.present) {
      map['alternate_greetings'] = Variable<String>(alternateGreetings.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (ttsVoice.present) {
      map['tts_voice'] = Variable<String>(ttsVoice.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    if (lorebook.present) {
      map['lorebook'] = Variable<String>(lorebook.value);
    }
    if (worldNames.present) {
      map['world_names'] = Variable<String>(worldNames.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CharactersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('personality: $personality, ')
          ..write('scenario: $scenario, ')
          ..write('firstMessage: $firstMessage, ')
          ..write('mesExample: $mesExample, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('postHistoryInstructions: $postHistoryInstructions, ')
          ..write('alternateGreetings: $alternateGreetings, ')
          ..write('tags: $tags, ')
          ..write('imagePath: $imagePath, ')
          ..write('ttsVoice: $ttsVoice, ')
          ..write('folderId: $folderId, ')
          ..write('lorebook: $lorebook, ')
          ..write('worldNames: $worldNames, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $GroupsTable extends Groups with TableInfo<$GroupsTable, Group> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _characterIdsMeta = const VerificationMeta(
    'characterIds',
  );
  @override
  late final GeneratedColumn<String> characterIds = GeneratedColumn<String>(
    'character_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _turnOrderMeta = const VerificationMeta(
    'turnOrder',
  );
  @override
  late final GeneratedColumn<String> turnOrder = GeneratedColumn<String>(
    'turn_order',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('roundRobin'),
  );
  static const VerificationMeta _autoAdvanceMeta = const VerificationMeta(
    'autoAdvance',
  );
  @override
  late final GeneratedColumn<bool> autoAdvance = GeneratedColumn<bool>(
    'auto_advance',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_advance" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _directorModeMeta = const VerificationMeta(
    'directorMode',
  );
  @override
  late final GeneratedColumn<bool> directorMode = GeneratedColumn<bool>(
    'director_mode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("director_mode" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _firstMessageMeta = const VerificationMeta(
    'firstMessage',
  );
  @override
  late final GeneratedColumn<String> firstMessage = GeneratedColumn<String>(
    'first_message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _scenarioMeta = const VerificationMeta(
    'scenario',
  );
  @override
  late final GeneratedColumn<String> scenario = GeneratedColumn<String>(
    'scenario',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _systemPromptMeta = const VerificationMeta(
    'systemPrompt',
  );
  @override
  late final GeneratedColumn<String> systemPrompt = GeneratedColumn<String>(
    'system_prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    characterIds,
    turnOrder,
    autoAdvance,
    directorMode,
    firstMessage,
    scenario,
    systemPrompt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<Group> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('character_ids')) {
      context.handle(
        _characterIdsMeta,
        characterIds.isAcceptableOrUnknown(
          data['character_ids']!,
          _characterIdsMeta,
        ),
      );
    }
    if (data.containsKey('turn_order')) {
      context.handle(
        _turnOrderMeta,
        turnOrder.isAcceptableOrUnknown(data['turn_order']!, _turnOrderMeta),
      );
    }
    if (data.containsKey('auto_advance')) {
      context.handle(
        _autoAdvanceMeta,
        autoAdvance.isAcceptableOrUnknown(
          data['auto_advance']!,
          _autoAdvanceMeta,
        ),
      );
    }
    if (data.containsKey('director_mode')) {
      context.handle(
        _directorModeMeta,
        directorMode.isAcceptableOrUnknown(
          data['director_mode']!,
          _directorModeMeta,
        ),
      );
    }
    if (data.containsKey('first_message')) {
      context.handle(
        _firstMessageMeta,
        firstMessage.isAcceptableOrUnknown(
          data['first_message']!,
          _firstMessageMeta,
        ),
      );
    }
    if (data.containsKey('scenario')) {
      context.handle(
        _scenarioMeta,
        scenario.isAcceptableOrUnknown(data['scenario']!, _scenarioMeta),
      );
    }
    if (data.containsKey('system_prompt')) {
      context.handle(
        _systemPromptMeta,
        systemPrompt.isAcceptableOrUnknown(
          data['system_prompt']!,
          _systemPromptMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Group map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Group(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      characterIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_ids'],
      )!,
      turnOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turn_order'],
      )!,
      autoAdvance: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_advance'],
      )!,
      directorMode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}director_mode'],
      )!,
      firstMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_message'],
      )!,
      scenario: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scenario'],
      )!,
      systemPrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}system_prompt'],
      )!,
    );
  }

  @override
  $GroupsTable createAlias(String alias) {
    return $GroupsTable(attachedDatabase, alias);
  }
}

class Group extends DataClass implements Insertable<Group> {
  final String id;
  final String name;
  final String characterIds;
  final String turnOrder;
  final bool autoAdvance;
  final bool directorMode;
  final String firstMessage;
  final String scenario;
  final String systemPrompt;
  const Group({
    required this.id,
    required this.name,
    required this.characterIds,
    required this.turnOrder,
    required this.autoAdvance,
    required this.directorMode,
    required this.firstMessage,
    required this.scenario,
    required this.systemPrompt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['character_ids'] = Variable<String>(characterIds);
    map['turn_order'] = Variable<String>(turnOrder);
    map['auto_advance'] = Variable<bool>(autoAdvance);
    map['director_mode'] = Variable<bool>(directorMode);
    map['first_message'] = Variable<String>(firstMessage);
    map['scenario'] = Variable<String>(scenario);
    map['system_prompt'] = Variable<String>(systemPrompt);
    return map;
  }

  GroupsCompanion toCompanion(bool nullToAbsent) {
    return GroupsCompanion(
      id: Value(id),
      name: Value(name),
      characterIds: Value(characterIds),
      turnOrder: Value(turnOrder),
      autoAdvance: Value(autoAdvance),
      directorMode: Value(directorMode),
      firstMessage: Value(firstMessage),
      scenario: Value(scenario),
      systemPrompt: Value(systemPrompt),
    );
  }

  factory Group.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Group(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      characterIds: serializer.fromJson<String>(json['characterIds']),
      turnOrder: serializer.fromJson<String>(json['turnOrder']),
      autoAdvance: serializer.fromJson<bool>(json['autoAdvance']),
      directorMode: serializer.fromJson<bool>(json['directorMode']),
      firstMessage: serializer.fromJson<String>(json['firstMessage']),
      scenario: serializer.fromJson<String>(json['scenario']),
      systemPrompt: serializer.fromJson<String>(json['systemPrompt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'characterIds': serializer.toJson<String>(characterIds),
      'turnOrder': serializer.toJson<String>(turnOrder),
      'autoAdvance': serializer.toJson<bool>(autoAdvance),
      'directorMode': serializer.toJson<bool>(directorMode),
      'firstMessage': serializer.toJson<String>(firstMessage),
      'scenario': serializer.toJson<String>(scenario),
      'systemPrompt': serializer.toJson<String>(systemPrompt),
    };
  }

  Group copyWith({
    String? id,
    String? name,
    String? characterIds,
    String? turnOrder,
    bool? autoAdvance,
    bool? directorMode,
    String? firstMessage,
    String? scenario,
    String? systemPrompt,
  }) => Group(
    id: id ?? this.id,
    name: name ?? this.name,
    characterIds: characterIds ?? this.characterIds,
    turnOrder: turnOrder ?? this.turnOrder,
    autoAdvance: autoAdvance ?? this.autoAdvance,
    directorMode: directorMode ?? this.directorMode,
    firstMessage: firstMessage ?? this.firstMessage,
    scenario: scenario ?? this.scenario,
    systemPrompt: systemPrompt ?? this.systemPrompt,
  );
  Group copyWithCompanion(GroupsCompanion data) {
    return Group(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      characterIds: data.characterIds.present
          ? data.characterIds.value
          : this.characterIds,
      turnOrder: data.turnOrder.present ? data.turnOrder.value : this.turnOrder,
      autoAdvance: data.autoAdvance.present
          ? data.autoAdvance.value
          : this.autoAdvance,
      directorMode: data.directorMode.present
          ? data.directorMode.value
          : this.directorMode,
      firstMessage: data.firstMessage.present
          ? data.firstMessage.value
          : this.firstMessage,
      scenario: data.scenario.present ? data.scenario.value : this.scenario,
      systemPrompt: data.systemPrompt.present
          ? data.systemPrompt.value
          : this.systemPrompt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Group(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('characterIds: $characterIds, ')
          ..write('turnOrder: $turnOrder, ')
          ..write('autoAdvance: $autoAdvance, ')
          ..write('directorMode: $directorMode, ')
          ..write('firstMessage: $firstMessage, ')
          ..write('scenario: $scenario, ')
          ..write('systemPrompt: $systemPrompt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    characterIds,
    turnOrder,
    autoAdvance,
    directorMode,
    firstMessage,
    scenario,
    systemPrompt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Group &&
          other.id == this.id &&
          other.name == this.name &&
          other.characterIds == this.characterIds &&
          other.turnOrder == this.turnOrder &&
          other.autoAdvance == this.autoAdvance &&
          other.directorMode == this.directorMode &&
          other.firstMessage == this.firstMessage &&
          other.scenario == this.scenario &&
          other.systemPrompt == this.systemPrompt);
}

class GroupsCompanion extends UpdateCompanion<Group> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> characterIds;
  final Value<String> turnOrder;
  final Value<bool> autoAdvance;
  final Value<bool> directorMode;
  final Value<String> firstMessage;
  final Value<String> scenario;
  final Value<String> systemPrompt;
  final Value<int> rowid;
  const GroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.characterIds = const Value.absent(),
    this.turnOrder = const Value.absent(),
    this.autoAdvance = const Value.absent(),
    this.directorMode = const Value.absent(),
    this.firstMessage = const Value.absent(),
    this.scenario = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupsCompanion.insert({
    required String id,
    required String name,
    this.characterIds = const Value.absent(),
    this.turnOrder = const Value.absent(),
    this.autoAdvance = const Value.absent(),
    this.directorMode = const Value.absent(),
    this.firstMessage = const Value.absent(),
    this.scenario = const Value.absent(),
    this.systemPrompt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Group> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? characterIds,
    Expression<String>? turnOrder,
    Expression<bool>? autoAdvance,
    Expression<bool>? directorMode,
    Expression<String>? firstMessage,
    Expression<String>? scenario,
    Expression<String>? systemPrompt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (characterIds != null) 'character_ids': characterIds,
      if (turnOrder != null) 'turn_order': turnOrder,
      if (autoAdvance != null) 'auto_advance': autoAdvance,
      if (directorMode != null) 'director_mode': directorMode,
      if (firstMessage != null) 'first_message': firstMessage,
      if (scenario != null) 'scenario': scenario,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? characterIds,
    Value<String>? turnOrder,
    Value<bool>? autoAdvance,
    Value<bool>? directorMode,
    Value<String>? firstMessage,
    Value<String>? scenario,
    Value<String>? systemPrompt,
    Value<int>? rowid,
  }) {
    return GroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      characterIds: characterIds ?? this.characterIds,
      turnOrder: turnOrder ?? this.turnOrder,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      directorMode: directorMode ?? this.directorMode,
      firstMessage: firstMessage ?? this.firstMessage,
      scenario: scenario ?? this.scenario,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (characterIds.present) {
      map['character_ids'] = Variable<String>(characterIds.value);
    }
    if (turnOrder.present) {
      map['turn_order'] = Variable<String>(turnOrder.value);
    }
    if (autoAdvance.present) {
      map['auto_advance'] = Variable<bool>(autoAdvance.value);
    }
    if (directorMode.present) {
      map['director_mode'] = Variable<bool>(directorMode.value);
    }
    if (firstMessage.present) {
      map['first_message'] = Variable<String>(firstMessage.value);
    }
    if (scenario.present) {
      map['scenario'] = Variable<String>(scenario.value);
    }
    if (systemPrompt.present) {
      map['system_prompt'] = Variable<String>(systemPrompt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('characterIds: $characterIds, ')
          ..write('turnOrder: $turnOrder, ')
          ..write('autoAdvance: $autoAdvance, ')
          ..write('directorMode: $directorMode, ')
          ..write('firstMessage: $firstMessage, ')
          ..write('scenario: $scenario, ')
          ..write('systemPrompt: $systemPrompt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _characterIdMeta = const VerificationMeta(
    'characterId',
  );
  @override
  late final GeneratedColumn<int> characterId = GeneratedColumn<int>(
    'character_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES characters (id)',
    ),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES "groups" (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorNoteMeta = const VerificationMeta(
    'authorNote',
  );
  @override
  late final GeneratedColumn<String> authorNote = GeneratedColumn<String>(
    'author_note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _authorNoteDepthMeta = const VerificationMeta(
    'authorNoteDepth',
  );
  @override
  late final GeneratedColumn<int> authorNoteDepth = GeneratedColumn<int>(
    'author_note_depth',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _parentSessionMeta = const VerificationMeta(
    'parentSession',
  );
  @override
  late final GeneratedColumn<String> parentSession = GeneratedColumn<String>(
    'parent_session',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _forkIndexMeta = const VerificationMeta(
    'forkIndex',
  );
  @override
  late final GeneratedColumn<int> forkIndex = GeneratedColumn<int>(
    'fork_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    characterId,
    groupId,
    name,
    description,
    authorNote,
    authorNoteDepth,
    parentSession,
    forkIndex,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('character_id')) {
      context.handle(
        _characterIdMeta,
        characterId.isAcceptableOrUnknown(
          data['character_id']!,
          _characterIdMeta,
        ),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('author_note')) {
      context.handle(
        _authorNoteMeta,
        authorNote.isAcceptableOrUnknown(data['author_note']!, _authorNoteMeta),
      );
    }
    if (data.containsKey('author_note_depth')) {
      context.handle(
        _authorNoteDepthMeta,
        authorNoteDepth.isAcceptableOrUnknown(
          data['author_note_depth']!,
          _authorNoteDepthMeta,
        ),
      );
    }
    if (data.containsKey('parent_session')) {
      context.handle(
        _parentSessionMeta,
        parentSession.isAcceptableOrUnknown(
          data['parent_session']!,
          _parentSessionMeta,
        ),
      );
    }
    if (data.containsKey('fork_index')) {
      context.handle(
        _forkIndexMeta,
        forkIndex.isAcceptableOrUnknown(data['fork_index']!, _forkIndexMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}character_id'],
      ),
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      authorNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_note'],
      )!,
      authorNoteDepth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}author_note_depth'],
      )!,
      parentSession: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_session'],
      ),
      forkIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fork_index'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final String id;
  final int? characterId;
  final String? groupId;
  final String? name;
  final String? description;
  final String authorNote;
  final int authorNoteDepth;
  final String? parentSession;
  final int? forkIndex;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Session({
    required this.id,
    this.characterId,
    this.groupId,
    this.name,
    this.description,
    required this.authorNote,
    required this.authorNoteDepth,
    this.parentSession,
    this.forkIndex,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || characterId != null) {
      map['character_id'] = Variable<int>(characterId);
    }
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['author_note'] = Variable<String>(authorNote);
    map['author_note_depth'] = Variable<int>(authorNoteDepth);
    if (!nullToAbsent || parentSession != null) {
      map['parent_session'] = Variable<String>(parentSession);
    }
    if (!nullToAbsent || forkIndex != null) {
      map['fork_index'] = Variable<int>(forkIndex);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      characterId: characterId == null && nullToAbsent
          ? const Value.absent()
          : Value(characterId),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      authorNote: Value(authorNote),
      authorNoteDepth: Value(authorNoteDepth),
      parentSession: parentSession == null && nullToAbsent
          ? const Value.absent()
          : Value(parentSession),
      forkIndex: forkIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(forkIndex),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      characterId: serializer.fromJson<int?>(json['characterId']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      name: serializer.fromJson<String?>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      authorNote: serializer.fromJson<String>(json['authorNote']),
      authorNoteDepth: serializer.fromJson<int>(json['authorNoteDepth']),
      parentSession: serializer.fromJson<String?>(json['parentSession']),
      forkIndex: serializer.fromJson<int?>(json['forkIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'characterId': serializer.toJson<int?>(characterId),
      'groupId': serializer.toJson<String?>(groupId),
      'name': serializer.toJson<String?>(name),
      'description': serializer.toJson<String?>(description),
      'authorNote': serializer.toJson<String>(authorNote),
      'authorNoteDepth': serializer.toJson<int>(authorNoteDepth),
      'parentSession': serializer.toJson<String?>(parentSession),
      'forkIndex': serializer.toJson<int?>(forkIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Session copyWith({
    String? id,
    Value<int?> characterId = const Value.absent(),
    Value<String?> groupId = const Value.absent(),
    Value<String?> name = const Value.absent(),
    Value<String?> description = const Value.absent(),
    String? authorNote,
    int? authorNoteDepth,
    Value<String?> parentSession = const Value.absent(),
    Value<int?> forkIndex = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Session(
    id: id ?? this.id,
    characterId: characterId.present ? characterId.value : this.characterId,
    groupId: groupId.present ? groupId.value : this.groupId,
    name: name.present ? name.value : this.name,
    description: description.present ? description.value : this.description,
    authorNote: authorNote ?? this.authorNote,
    authorNoteDepth: authorNoteDepth ?? this.authorNoteDepth,
    parentSession: parentSession.present
        ? parentSession.value
        : this.parentSession,
    forkIndex: forkIndex.present ? forkIndex.value : this.forkIndex,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      authorNote: data.authorNote.present
          ? data.authorNote.value
          : this.authorNote,
      authorNoteDepth: data.authorNoteDepth.present
          ? data.authorNoteDepth.value
          : this.authorNoteDepth,
      parentSession: data.parentSession.present
          ? data.parentSession.value
          : this.parentSession,
      forkIndex: data.forkIndex.present ? data.forkIndex.value : this.forkIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('authorNote: $authorNote, ')
          ..write('authorNoteDepth: $authorNoteDepth, ')
          ..write('parentSession: $parentSession, ')
          ..write('forkIndex: $forkIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    characterId,
    groupId,
    name,
    description,
    authorNote,
    authorNoteDepth,
    parentSession,
    forkIndex,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.characterId == this.characterId &&
          other.groupId == this.groupId &&
          other.name == this.name &&
          other.description == this.description &&
          other.authorNote == this.authorNote &&
          other.authorNoteDepth == this.authorNoteDepth &&
          other.parentSession == this.parentSession &&
          other.forkIndex == this.forkIndex &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<int?> characterId;
  final Value<String?> groupId;
  final Value<String?> name;
  final Value<String?> description;
  final Value<String> authorNote;
  final Value<int> authorNoteDepth;
  final Value<String?> parentSession;
  final Value<int?> forkIndex;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.characterId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.authorNote = const Value.absent(),
    this.authorNoteDepth = const Value.absent(),
    this.parentSession = const Value.absent(),
    this.forkIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    this.characterId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.authorNote = const Value.absent(),
    this.authorNoteDepth = const Value.absent(),
    this.parentSession = const Value.absent(),
    this.forkIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<int>? characterId,
    Expression<String>? groupId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? authorNote,
    Expression<int>? authorNoteDepth,
    Expression<String>? parentSession,
    Expression<int>? forkIndex,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (characterId != null) 'character_id': characterId,
      if (groupId != null) 'group_id': groupId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (authorNote != null) 'author_note': authorNote,
      if (authorNoteDepth != null) 'author_note_depth': authorNoteDepth,
      if (parentSession != null) 'parent_session': parentSession,
      if (forkIndex != null) 'fork_index': forkIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<int?>? characterId,
    Value<String?>? groupId,
    Value<String?>? name,
    Value<String?>? description,
    Value<String>? authorNote,
    Value<int>? authorNoteDepth,
    Value<String?>? parentSession,
    Value<int?>? forkIndex,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      description: description ?? this.description,
      authorNote: authorNote ?? this.authorNote,
      authorNoteDepth: authorNoteDepth ?? this.authorNoteDepth,
      parentSession: parentSession ?? this.parentSession,
      forkIndex: forkIndex ?? this.forkIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<int>(characterId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (authorNote.present) {
      map['author_note'] = Variable<String>(authorNote.value);
    }
    if (authorNoteDepth.present) {
      map['author_note_depth'] = Variable<int>(authorNoteDepth.value);
    }
    if (parentSession.present) {
      map['parent_session'] = Variable<String>(parentSession.value);
    }
    if (forkIndex.present) {
      map['fork_index'] = Variable<int>(forkIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('authorNote: $authorNote, ')
          ..write('authorNoteDepth: $authorNoteDepth, ')
          ..write('parentSession: $parentSession, ')
          ..write('forkIndex: $forkIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderMeta = const VerificationMeta('sender');
  @override
  late final GeneratedColumn<String> sender = GeneratedColumn<String>(
    'sender',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isUserMeta = const VerificationMeta('isUser');
  @override
  late final GeneratedColumn<bool> isUser = GeneratedColumn<bool>(
    'is_user',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_user" IN (0, 1))',
    ),
  );
  static const VerificationMeta _characterIdMeta = const VerificationMeta(
    'characterId',
  );
  @override
  late final GeneratedColumn<String> characterId = GeneratedColumn<String>(
    'character_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _swipesMeta = const VerificationMeta('swipes');
  @override
  late final GeneratedColumn<String> swipes = GeneratedColumn<String>(
    'swipes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _swipeIndexMeta = const VerificationMeta(
    'swipeIndex',
  );
  @override
  late final GeneratedColumn<int> swipeIndex = GeneratedColumn<int>(
    'swipe_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _swipeDurationsMeta = const VerificationMeta(
    'swipeDurations',
  );
  @override
  late final GeneratedColumn<String> swipeDurations = GeneratedColumn<String>(
    'swipe_durations',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    position,
    sender,
    isUser,
    characterId,
    swipes,
    swipeIndex,
    swipeDurations,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('sender')) {
      context.handle(
        _senderMeta,
        sender.isAcceptableOrUnknown(data['sender']!, _senderMeta),
      );
    } else if (isInserting) {
      context.missing(_senderMeta);
    }
    if (data.containsKey('is_user')) {
      context.handle(
        _isUserMeta,
        isUser.isAcceptableOrUnknown(data['is_user']!, _isUserMeta),
      );
    } else if (isInserting) {
      context.missing(_isUserMeta);
    }
    if (data.containsKey('character_id')) {
      context.handle(
        _characterIdMeta,
        characterId.isAcceptableOrUnknown(
          data['character_id']!,
          _characterIdMeta,
        ),
      );
    }
    if (data.containsKey('swipes')) {
      context.handle(
        _swipesMeta,
        swipes.isAcceptableOrUnknown(data['swipes']!, _swipesMeta),
      );
    }
    if (data.containsKey('swipe_index')) {
      context.handle(
        _swipeIndexMeta,
        swipeIndex.isAcceptableOrUnknown(data['swipe_index']!, _swipeIndexMeta),
      );
    }
    if (data.containsKey('swipe_durations')) {
      context.handle(
        _swipeDurationsMeta,
        swipeDurations.isAcceptableOrUnknown(
          data['swipe_durations']!,
          _swipeDurationsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      sender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender'],
      )!,
      isUser: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_user'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_id'],
      ),
      swipes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}swipes'],
      )!,
      swipeIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}swipe_index'],
      )!,
      swipeDurations: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}swipe_durations'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final int id;
  final String sessionId;
  final int position;
  final String sender;
  final bool isUser;
  final String? characterId;
  final String swipes;
  final int swipeIndex;
  final String swipeDurations;
  const Message({
    required this.id,
    required this.sessionId,
    required this.position,
    required this.sender,
    required this.isUser,
    this.characterId,
    required this.swipes,
    required this.swipeIndex,
    required this.swipeDurations,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['position'] = Variable<int>(position);
    map['sender'] = Variable<String>(sender);
    map['is_user'] = Variable<bool>(isUser);
    if (!nullToAbsent || characterId != null) {
      map['character_id'] = Variable<String>(characterId);
    }
    map['swipes'] = Variable<String>(swipes);
    map['swipe_index'] = Variable<int>(swipeIndex);
    map['swipe_durations'] = Variable<String>(swipeDurations);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      position: Value(position),
      sender: Value(sender),
      isUser: Value(isUser),
      characterId: characterId == null && nullToAbsent
          ? const Value.absent()
          : Value(characterId),
      swipes: Value(swipes),
      swipeIndex: Value(swipeIndex),
      swipeDurations: Value(swipeDurations),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      position: serializer.fromJson<int>(json['position']),
      sender: serializer.fromJson<String>(json['sender']),
      isUser: serializer.fromJson<bool>(json['isUser']),
      characterId: serializer.fromJson<String?>(json['characterId']),
      swipes: serializer.fromJson<String>(json['swipes']),
      swipeIndex: serializer.fromJson<int>(json['swipeIndex']),
      swipeDurations: serializer.fromJson<String>(json['swipeDurations']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'position': serializer.toJson<int>(position),
      'sender': serializer.toJson<String>(sender),
      'isUser': serializer.toJson<bool>(isUser),
      'characterId': serializer.toJson<String?>(characterId),
      'swipes': serializer.toJson<String>(swipes),
      'swipeIndex': serializer.toJson<int>(swipeIndex),
      'swipeDurations': serializer.toJson<String>(swipeDurations),
    };
  }

  Message copyWith({
    int? id,
    String? sessionId,
    int? position,
    String? sender,
    bool? isUser,
    Value<String?> characterId = const Value.absent(),
    String? swipes,
    int? swipeIndex,
    String? swipeDurations,
  }) => Message(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    position: position ?? this.position,
    sender: sender ?? this.sender,
    isUser: isUser ?? this.isUser,
    characterId: characterId.present ? characterId.value : this.characterId,
    swipes: swipes ?? this.swipes,
    swipeIndex: swipeIndex ?? this.swipeIndex,
    swipeDurations: swipeDurations ?? this.swipeDurations,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      position: data.position.present ? data.position.value : this.position,
      sender: data.sender.present ? data.sender.value : this.sender,
      isUser: data.isUser.present ? data.isUser.value : this.isUser,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      swipes: data.swipes.present ? data.swipes.value : this.swipes,
      swipeIndex: data.swipeIndex.present
          ? data.swipeIndex.value
          : this.swipeIndex,
      swipeDurations: data.swipeDurations.present
          ? data.swipeDurations.value
          : this.swipeDurations,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('position: $position, ')
          ..write('sender: $sender, ')
          ..write('isUser: $isUser, ')
          ..write('characterId: $characterId, ')
          ..write('swipes: $swipes, ')
          ..write('swipeIndex: $swipeIndex, ')
          ..write('swipeDurations: $swipeDurations')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    position,
    sender,
    isUser,
    characterId,
    swipes,
    swipeIndex,
    swipeDurations,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.position == this.position &&
          other.sender == this.sender &&
          other.isUser == this.isUser &&
          other.characterId == this.characterId &&
          other.swipes == this.swipes &&
          other.swipeIndex == this.swipeIndex &&
          other.swipeDurations == this.swipeDurations);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<int> position;
  final Value<String> sender;
  final Value<bool> isUser;
  final Value<String?> characterId;
  final Value<String> swipes;
  final Value<int> swipeIndex;
  final Value<String> swipeDurations;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.position = const Value.absent(),
    this.sender = const Value.absent(),
    this.isUser = const Value.absent(),
    this.characterId = const Value.absent(),
    this.swipes = const Value.absent(),
    this.swipeIndex = const Value.absent(),
    this.swipeDurations = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required int position,
    required String sender,
    required bool isUser,
    this.characterId = const Value.absent(),
    this.swipes = const Value.absent(),
    this.swipeIndex = const Value.absent(),
    this.swipeDurations = const Value.absent(),
  }) : sessionId = Value(sessionId),
       position = Value(position),
       sender = Value(sender),
       isUser = Value(isUser);
  static Insertable<Message> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<int>? position,
    Expression<String>? sender,
    Expression<bool>? isUser,
    Expression<String>? characterId,
    Expression<String>? swipes,
    Expression<int>? swipeIndex,
    Expression<String>? swipeDurations,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (position != null) 'position': position,
      if (sender != null) 'sender': sender,
      if (isUser != null) 'is_user': isUser,
      if (characterId != null) 'character_id': characterId,
      if (swipes != null) 'swipes': swipes,
      if (swipeIndex != null) 'swipe_index': swipeIndex,
      if (swipeDurations != null) 'swipe_durations': swipeDurations,
    });
  }

  MessagesCompanion copyWith({
    Value<int>? id,
    Value<String>? sessionId,
    Value<int>? position,
    Value<String>? sender,
    Value<bool>? isUser,
    Value<String?>? characterId,
    Value<String>? swipes,
    Value<int>? swipeIndex,
    Value<String>? swipeDurations,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      position: position ?? this.position,
      sender: sender ?? this.sender,
      isUser: isUser ?? this.isUser,
      characterId: characterId ?? this.characterId,
      swipes: swipes ?? this.swipes,
      swipeIndex: swipeIndex ?? this.swipeIndex,
      swipeDurations: swipeDurations ?? this.swipeDurations,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (isUser.present) {
      map['is_user'] = Variable<bool>(isUser.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<String>(characterId.value);
    }
    if (swipes.present) {
      map['swipes'] = Variable<String>(swipes.value);
    }
    if (swipeIndex.present) {
      map['swipe_index'] = Variable<int>(swipeIndex.value);
    }
    if (swipeDurations.present) {
      map['swipe_durations'] = Variable<String>(swipeDurations.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('position: $position, ')
          ..write('sender: $sender, ')
          ..write('isUser: $isUser, ')
          ..write('characterId: $characterId, ')
          ..write('swipes: $swipes, ')
          ..write('swipeIndex: $swipeIndex, ')
          ..write('swipeDurations: $swipeDurations')
          ..write(')'))
        .toString();
  }
}

class $PersonasTable extends Personas with TableInfo<$PersonasTable, Persona> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('User'),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _personaMeta = const VerificationMeta(
    'persona',
  );
  @override
  late final GeneratedColumn<String> persona = GeneratedColumn<String>(
    'persona',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _avatarPathMeta = const VerificationMeta(
    'avatarPath',
  );
  @override
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
    'avatar_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    name,
    description,
    persona,
    avatarPath,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'personas';
  @override
  VerificationContext validateIntegrity(
    Insertable<Persona> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('persona')) {
      context.handle(
        _personaMeta,
        persona.isAcceptableOrUnknown(data['persona']!, _personaMeta),
      );
    }
    if (data.containsKey('avatar_path')) {
      context.handle(
        _avatarPathMeta,
        avatarPath.isAcceptableOrUnknown(data['avatar_path']!, _avatarPathMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Persona map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Persona(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      persona: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persona'],
      )!,
      avatarPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_path'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $PersonasTable createAlias(String alias) {
    return $PersonasTable(attachedDatabase, alias);
  }
}

class Persona extends DataClass implements Insertable<Persona> {
  final String id;
  final String title;
  final String name;
  final String description;
  final String persona;
  final String? avatarPath;
  final bool isActive;
  const Persona({
    required this.id,
    required this.title,
    required this.name,
    required this.description,
    required this.persona,
    this.avatarPath,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['persona'] = Variable<String>(persona);
    if (!nullToAbsent || avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  PersonasCompanion toCompanion(bool nullToAbsent) {
    return PersonasCompanion(
      id: Value(id),
      title: Value(title),
      name: Value(name),
      description: Value(description),
      persona: Value(persona),
      avatarPath: avatarPath == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarPath),
      isActive: Value(isActive),
    );
  }

  factory Persona.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Persona(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      persona: serializer.fromJson<String>(json['persona']),
      avatarPath: serializer.fromJson<String?>(json['avatarPath']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'persona': serializer.toJson<String>(persona),
      'avatarPath': serializer.toJson<String?>(avatarPath),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Persona copyWith({
    String? id,
    String? title,
    String? name,
    String? description,
    String? persona,
    Value<String?> avatarPath = const Value.absent(),
    bool? isActive,
  }) => Persona(
    id: id ?? this.id,
    title: title ?? this.title,
    name: name ?? this.name,
    description: description ?? this.description,
    persona: persona ?? this.persona,
    avatarPath: avatarPath.present ? avatarPath.value : this.avatarPath,
    isActive: isActive ?? this.isActive,
  );
  Persona copyWithCompanion(PersonasCompanion data) {
    return Persona(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      persona: data.persona.present ? data.persona.value : this.persona,
      avatarPath: data.avatarPath.present
          ? data.avatarPath.value
          : this.avatarPath,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Persona(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('persona: $persona, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, name, description, persona, avatarPath, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Persona &&
          other.id == this.id &&
          other.title == this.title &&
          other.name == this.name &&
          other.description == this.description &&
          other.persona == this.persona &&
          other.avatarPath == this.avatarPath &&
          other.isActive == this.isActive);
}

class PersonasCompanion extends UpdateCompanion<Persona> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> name;
  final Value<String> description;
  final Value<String> persona;
  final Value<String?> avatarPath;
  final Value<bool> isActive;
  final Value<int> rowid;
  const PersonasCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.persona = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonasCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.persona = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<Persona> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? persona,
    Expression<String>? avatarPath,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (persona != null) 'persona': persona,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonasCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? name,
    Value<String>? description,
    Value<String>? persona,
    Value<String?>? avatarPath,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return PersonasCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      name: name ?? this.name,
      description: description ?? this.description,
      persona: persona ?? this.persona,
      avatarPath: avatarPath ?? this.avatarPath,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (persona.present) {
      map['persona'] = Variable<String>(persona.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonasCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('persona: $persona, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorldsTable extends Worlds with TableInfo<$WorldsTable, World> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorldsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _lorebookMeta = const VerificationMeta(
    'lorebook',
  );
  @override
  late final GeneratedColumn<String> lorebook = GeneratedColumn<String>(
    'lorebook',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedCharacterNameMeta =
      const VerificationMeta('linkedCharacterName');
  @override
  late final GeneratedColumn<String> linkedCharacterName =
      GeneratedColumn<String>(
        'linked_character_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    lorebook,
    linkedCharacterName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'worlds';
  @override
  VerificationContext validateIntegrity(
    Insertable<World> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('lorebook')) {
      context.handle(
        _lorebookMeta,
        lorebook.isAcceptableOrUnknown(data['lorebook']!, _lorebookMeta),
      );
    }
    if (data.containsKey('linked_character_name')) {
      context.handle(
        _linkedCharacterNameMeta,
        linkedCharacterName.isAcceptableOrUnknown(
          data['linked_character_name']!,
          _linkedCharacterNameMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  World map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return World(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      lorebook: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lorebook'],
      ),
      linkedCharacterName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_character_name'],
      ),
    );
  }

  @override
  $WorldsTable createAlias(String alias) {
    return $WorldsTable(attachedDatabase, alias);
  }
}

class World extends DataClass implements Insertable<World> {
  final int id;
  final String name;
  final String description;
  final String? lorebook;
  final String? linkedCharacterName;
  const World({
    required this.id,
    required this.name,
    required this.description,
    this.lorebook,
    this.linkedCharacterName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || lorebook != null) {
      map['lorebook'] = Variable<String>(lorebook);
    }
    if (!nullToAbsent || linkedCharacterName != null) {
      map['linked_character_name'] = Variable<String>(linkedCharacterName);
    }
    return map;
  }

  WorldsCompanion toCompanion(bool nullToAbsent) {
    return WorldsCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      lorebook: lorebook == null && nullToAbsent
          ? const Value.absent()
          : Value(lorebook),
      linkedCharacterName: linkedCharacterName == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedCharacterName),
    );
  }

  factory World.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return World(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      lorebook: serializer.fromJson<String?>(json['lorebook']),
      linkedCharacterName: serializer.fromJson<String?>(
        json['linkedCharacterName'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'lorebook': serializer.toJson<String?>(lorebook),
      'linkedCharacterName': serializer.toJson<String?>(linkedCharacterName),
    };
  }

  World copyWith({
    int? id,
    String? name,
    String? description,
    Value<String?> lorebook = const Value.absent(),
    Value<String?> linkedCharacterName = const Value.absent(),
  }) => World(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    lorebook: lorebook.present ? lorebook.value : this.lorebook,
    linkedCharacterName: linkedCharacterName.present
        ? linkedCharacterName.value
        : this.linkedCharacterName,
  );
  World copyWithCompanion(WorldsCompanion data) {
    return World(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      lorebook: data.lorebook.present ? data.lorebook.value : this.lorebook,
      linkedCharacterName: data.linkedCharacterName.present
          ? data.linkedCharacterName.value
          : this.linkedCharacterName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('World(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('lorebook: $lorebook, ')
          ..write('linkedCharacterName: $linkedCharacterName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, lorebook, linkedCharacterName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is World &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.lorebook == this.lorebook &&
          other.linkedCharacterName == this.linkedCharacterName);
}

class WorldsCompanion extends UpdateCompanion<World> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> description;
  final Value<String?> lorebook;
  final Value<String?> linkedCharacterName;
  const WorldsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.lorebook = const Value.absent(),
    this.linkedCharacterName = const Value.absent(),
  });
  WorldsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.lorebook = const Value.absent(),
    this.linkedCharacterName = const Value.absent(),
  }) : name = Value(name);
  static Insertable<World> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? lorebook,
    Expression<String>? linkedCharacterName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (lorebook != null) 'lorebook': lorebook,
      if (linkedCharacterName != null)
        'linked_character_name': linkedCharacterName,
    });
  }

  WorldsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? description,
    Value<String?>? lorebook,
    Value<String?>? linkedCharacterName,
  }) {
    return WorldsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      lorebook: lorebook ?? this.lorebook,
      linkedCharacterName: linkedCharacterName ?? this.linkedCharacterName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (lorebook.present) {
      map['lorebook'] = Variable<String>(lorebook.value);
    }
    if (linkedCharacterName.present) {
      map['linked_character_name'] = Variable<String>(
        linkedCharacterName.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorldsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('lorebook: $lorebook, ')
          ..write('linkedCharacterName: $linkedCharacterName')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $CharactersTable characters = $CharactersTable(this);
  late final $GroupsTable groups = $GroupsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $PersonasTable personas = $PersonasTable(this);
  late final $WorldsTable worlds = $WorldsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    folders,
    characters,
    groups,
    sessions,
    messages,
    personas,
    worlds,
  ];
}

typedef $$FoldersTableCreateCompanionBuilder =
    FoldersCompanion Function({
      Value<int> id,
      required String name,
      Value<int?> parentId,
    });
typedef $$FoldersTableUpdateCompanionBuilder =
    FoldersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int?> parentId,
    });

final class $$FoldersTableReferences
    extends BaseReferences<_$AppDatabase, $FoldersTable, Folder> {
  $$FoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CharactersTable, List<Character>>
  _charactersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.characters,
    aliasName: $_aliasNameGenerator(db.folders.id, db.characters.folderId),
  );

  $$CharactersTableProcessedTableManager get charactersRefs {
    final manager = $$CharactersTableTableManager(
      $_db,
      $_db.characters,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_charactersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> charactersRefs(
    Expression<bool> Function($$CharactersTableFilterComposer f) f,
  ) {
    final $$CharactersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.characters,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CharactersTableFilterComposer(
            $db: $db,
            $table: $db.characters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  Expression<T> charactersRefs<T extends Object>(
    Expression<T> Function($$CharactersTableAnnotationComposer a) f,
  ) {
    final $$CharactersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.characters,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CharactersTableAnnotationComposer(
            $db: $db,
            $table: $db.characters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoldersTable,
          Folder,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (Folder, $$FoldersTableReferences),
          Folder,
          PrefetchHooks Function({bool charactersRefs})
        > {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
              }) => FoldersCompanion(id: id, name: name, parentId: parentId),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int?> parentId = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                name: name,
                parentId: parentId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({charactersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (charactersRefs) db.characters],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (charactersRefs)
                    await $_getPrefetchedData<Folder, $FoldersTable, Character>(
                      currentTable: table,
                      referencedTable: $$FoldersTableReferences
                          ._charactersRefsTable(db),
                      managerFromTypedResult: (p0) => $$FoldersTableReferences(
                        db,
                        table,
                        p0,
                      ).charactersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoldersTable,
      Folder,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (Folder, $$FoldersTableReferences),
      Folder,
      PrefetchHooks Function({bool charactersRefs})
    >;
typedef $$CharactersTableCreateCompanionBuilder =
    CharactersCompanion Function({
      Value<int> id,
      required String name,
      Value<String> description,
      Value<String> personality,
      Value<String> scenario,
      Value<String> firstMessage,
      Value<String> mesExample,
      Value<String> systemPrompt,
      Value<String> postHistoryInstructions,
      Value<String> alternateGreetings,
      Value<String> tags,
      Value<String?> imagePath,
      Value<String?> ttsVoice,
      Value<int?> folderId,
      Value<String?> lorebook,
      Value<String> worldNames,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$CharactersTableUpdateCompanionBuilder =
    CharactersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> description,
      Value<String> personality,
      Value<String> scenario,
      Value<String> firstMessage,
      Value<String> mesExample,
      Value<String> systemPrompt,
      Value<String> postHistoryInstructions,
      Value<String> alternateGreetings,
      Value<String> tags,
      Value<String?> imagePath,
      Value<String?> ttsVoice,
      Value<int?> folderId,
      Value<String?> lorebook,
      Value<String> worldNames,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$CharactersTableReferences
    extends BaseReferences<_$AppDatabase, $CharactersTable, Character> {
  $$CharactersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoldersTable _folderIdTable(_$AppDatabase db) => db.folders
      .createAlias($_aliasNameGenerator(db.characters.folderId, db.folders.id));

  $$FoldersTableProcessedTableManager? get folderId {
    final $_column = $_itemColumn<int>('folder_id');
    if ($_column == null) return null;
    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SessionsTable, List<Session>> _sessionsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.sessions,
    aliasName: $_aliasNameGenerator(db.characters.id, db.sessions.characterId),
  );

  $$SessionsTableProcessedTableManager get sessionsRefs {
    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.characterId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CharactersTableFilterComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personality => $composableBuilder(
    column: $table.personality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scenario => $composableBuilder(
    column: $table.scenario,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstMessage => $composableBuilder(
    column: $table.firstMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mesExample => $composableBuilder(
    column: $table.mesExample,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get postHistoryInstructions => $composableBuilder(
    column: $table.postHistoryInstructions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alternateGreetings => $composableBuilder(
    column: $table.alternateGreetings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ttsVoice => $composableBuilder(
    column: $table.ttsVoice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lorebook => $composableBuilder(
    column: $table.lorebook,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get worldNames => $composableBuilder(
    column: $table.worldNames,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FoldersTableFilterComposer get folderId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> sessionsRefs(
    Expression<bool> Function($$SessionsTableFilterComposer f) f,
  ) {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.characterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CharactersTableOrderingComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personality => $composableBuilder(
    column: $table.personality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scenario => $composableBuilder(
    column: $table.scenario,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstMessage => $composableBuilder(
    column: $table.firstMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mesExample => $composableBuilder(
    column: $table.mesExample,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get postHistoryInstructions => $composableBuilder(
    column: $table.postHistoryInstructions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alternateGreetings => $composableBuilder(
    column: $table.alternateGreetings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ttsVoice => $composableBuilder(
    column: $table.ttsVoice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lorebook => $composableBuilder(
    column: $table.lorebook,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get worldNames => $composableBuilder(
    column: $table.worldNames,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoldersTableOrderingComposer get folderId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableOrderingComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CharactersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get personality => $composableBuilder(
    column: $table.personality,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scenario =>
      $composableBuilder(column: $table.scenario, builder: (column) => column);

  GeneratedColumn<String> get firstMessage => $composableBuilder(
    column: $table.firstMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mesExample => $composableBuilder(
    column: $table.mesExample,
    builder: (column) => column,
  );

  GeneratedColumn<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get postHistoryInstructions => $composableBuilder(
    column: $table.postHistoryInstructions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alternateGreetings => $composableBuilder(
    column: $table.alternateGreetings,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get ttsVoice =>
      $composableBuilder(column: $table.ttsVoice, builder: (column) => column);

  GeneratedColumn<String> get lorebook =>
      $composableBuilder(column: $table.lorebook, builder: (column) => column);

  GeneratedColumn<String> get worldNames => $composableBuilder(
    column: $table.worldNames,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$FoldersTableAnnotationComposer get folderId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> sessionsRefs<T extends Object>(
    Expression<T> Function($$SessionsTableAnnotationComposer a) f,
  ) {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.characterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CharactersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CharactersTable,
          Character,
          $$CharactersTableFilterComposer,
          $$CharactersTableOrderingComposer,
          $$CharactersTableAnnotationComposer,
          $$CharactersTableCreateCompanionBuilder,
          $$CharactersTableUpdateCompanionBuilder,
          (Character, $$CharactersTableReferences),
          Character,
          PrefetchHooks Function({bool folderId, bool sessionsRefs})
        > {
  $$CharactersTableTableManager(_$AppDatabase db, $CharactersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CharactersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CharactersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CharactersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> personality = const Value.absent(),
                Value<String> scenario = const Value.absent(),
                Value<String> firstMessage = const Value.absent(),
                Value<String> mesExample = const Value.absent(),
                Value<String> systemPrompt = const Value.absent(),
                Value<String> postHistoryInstructions = const Value.absent(),
                Value<String> alternateGreetings = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String?> ttsVoice = const Value.absent(),
                Value<int?> folderId = const Value.absent(),
                Value<String?> lorebook = const Value.absent(),
                Value<String> worldNames = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CharactersCompanion(
                id: id,
                name: name,
                description: description,
                personality: personality,
                scenario: scenario,
                firstMessage: firstMessage,
                mesExample: mesExample,
                systemPrompt: systemPrompt,
                postHistoryInstructions: postHistoryInstructions,
                alternateGreetings: alternateGreetings,
                tags: tags,
                imagePath: imagePath,
                ttsVoice: ttsVoice,
                folderId: folderId,
                lorebook: lorebook,
                worldNames: worldNames,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> description = const Value.absent(),
                Value<String> personality = const Value.absent(),
                Value<String> scenario = const Value.absent(),
                Value<String> firstMessage = const Value.absent(),
                Value<String> mesExample = const Value.absent(),
                Value<String> systemPrompt = const Value.absent(),
                Value<String> postHistoryInstructions = const Value.absent(),
                Value<String> alternateGreetings = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String?> ttsVoice = const Value.absent(),
                Value<int?> folderId = const Value.absent(),
                Value<String?> lorebook = const Value.absent(),
                Value<String> worldNames = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CharactersCompanion.insert(
                id: id,
                name: name,
                description: description,
                personality: personality,
                scenario: scenario,
                firstMessage: firstMessage,
                mesExample: mesExample,
                systemPrompt: systemPrompt,
                postHistoryInstructions: postHistoryInstructions,
                alternateGreetings: alternateGreetings,
                tags: tags,
                imagePath: imagePath,
                ttsVoice: ttsVoice,
                folderId: folderId,
                lorebook: lorebook,
                worldNames: worldNames,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CharactersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({folderId = false, sessionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (sessionsRefs) db.sessions],
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
                    if (folderId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.folderId,
                                referencedTable: $$CharactersTableReferences
                                    ._folderIdTable(db),
                                referencedColumn: $$CharactersTableReferences
                                    ._folderIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionsRefs)
                    await $_getPrefetchedData<
                      Character,
                      $CharactersTable,
                      Session
                    >(
                      currentTable: table,
                      referencedTable: $$CharactersTableReferences
                          ._sessionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CharactersTableReferences(
                            db,
                            table,
                            p0,
                          ).sessionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.characterId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CharactersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CharactersTable,
      Character,
      $$CharactersTableFilterComposer,
      $$CharactersTableOrderingComposer,
      $$CharactersTableAnnotationComposer,
      $$CharactersTableCreateCompanionBuilder,
      $$CharactersTableUpdateCompanionBuilder,
      (Character, $$CharactersTableReferences),
      Character,
      PrefetchHooks Function({bool folderId, bool sessionsRefs})
    >;
typedef $$GroupsTableCreateCompanionBuilder =
    GroupsCompanion Function({
      required String id,
      required String name,
      Value<String> characterIds,
      Value<String> turnOrder,
      Value<bool> autoAdvance,
      Value<bool> directorMode,
      Value<String> firstMessage,
      Value<String> scenario,
      Value<String> systemPrompt,
      Value<int> rowid,
    });
typedef $$GroupsTableUpdateCompanionBuilder =
    GroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> characterIds,
      Value<String> turnOrder,
      Value<bool> autoAdvance,
      Value<bool> directorMode,
      Value<String> firstMessage,
      Value<String> scenario,
      Value<String> systemPrompt,
      Value<int> rowid,
    });

final class $$GroupsTableReferences
    extends BaseReferences<_$AppDatabase, $GroupsTable, Group> {
  $$GroupsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SessionsTable, List<Session>> _sessionsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.sessions,
    aliasName: $_aliasNameGenerator(db.groups.id, db.sessions.groupId),
  );

  $$SessionsTableProcessedTableManager get sessionsRefs {
    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GroupsTableFilterComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get characterIds => $composableBuilder(
    column: $table.characterIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get turnOrder => $composableBuilder(
    column: $table.turnOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoAdvance => $composableBuilder(
    column: $table.autoAdvance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get directorMode => $composableBuilder(
    column: $table.directorMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstMessage => $composableBuilder(
    column: $table.firstMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scenario => $composableBuilder(
    column: $table.scenario,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sessionsRefs(
    Expression<bool> Function($$SessionsTableFilterComposer f) f,
  ) {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get characterIds => $composableBuilder(
    column: $table.characterIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get turnOrder => $composableBuilder(
    column: $table.turnOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoAdvance => $composableBuilder(
    column: $table.autoAdvance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get directorMode => $composableBuilder(
    column: $table.directorMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstMessage => $composableBuilder(
    column: $table.firstMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scenario => $composableBuilder(
    column: $table.scenario,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get characterIds => $composableBuilder(
    column: $table.characterIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get turnOrder =>
      $composableBuilder(column: $table.turnOrder, builder: (column) => column);

  GeneratedColumn<bool> get autoAdvance => $composableBuilder(
    column: $table.autoAdvance,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get directorMode => $composableBuilder(
    column: $table.directorMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get firstMessage => $composableBuilder(
    column: $table.firstMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scenario =>
      $composableBuilder(column: $table.scenario, builder: (column) => column);

  GeneratedColumn<String> get systemPrompt => $composableBuilder(
    column: $table.systemPrompt,
    builder: (column) => column,
  );

  Expression<T> sessionsRefs<T extends Object>(
    Expression<T> Function($$SessionsTableAnnotationComposer a) f,
  ) {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupsTable,
          Group,
          $$GroupsTableFilterComposer,
          $$GroupsTableOrderingComposer,
          $$GroupsTableAnnotationComposer,
          $$GroupsTableCreateCompanionBuilder,
          $$GroupsTableUpdateCompanionBuilder,
          (Group, $$GroupsTableReferences),
          Group,
          PrefetchHooks Function({bool sessionsRefs})
        > {
  $$GroupsTableTableManager(_$AppDatabase db, $GroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> characterIds = const Value.absent(),
                Value<String> turnOrder = const Value.absent(),
                Value<bool> autoAdvance = const Value.absent(),
                Value<bool> directorMode = const Value.absent(),
                Value<String> firstMessage = const Value.absent(),
                Value<String> scenario = const Value.absent(),
                Value<String> systemPrompt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupsCompanion(
                id: id,
                name: name,
                characterIds: characterIds,
                turnOrder: turnOrder,
                autoAdvance: autoAdvance,
                directorMode: directorMode,
                firstMessage: firstMessage,
                scenario: scenario,
                systemPrompt: systemPrompt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> characterIds = const Value.absent(),
                Value<String> turnOrder = const Value.absent(),
                Value<bool> autoAdvance = const Value.absent(),
                Value<bool> directorMode = const Value.absent(),
                Value<String> firstMessage = const Value.absent(),
                Value<String> scenario = const Value.absent(),
                Value<String> systemPrompt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupsCompanion.insert(
                id: id,
                name: name,
                characterIds: characterIds,
                turnOrder: turnOrder,
                autoAdvance: autoAdvance,
                directorMode: directorMode,
                firstMessage: firstMessage,
                scenario: scenario,
                systemPrompt: systemPrompt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$GroupsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({sessionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (sessionsRefs) db.sessions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionsRefs)
                    await $_getPrefetchedData<Group, $GroupsTable, Session>(
                      currentTable: table,
                      referencedTable: $$GroupsTableReferences
                          ._sessionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$GroupsTableReferences(db, table, p0).sessionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.groupId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$GroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupsTable,
      Group,
      $$GroupsTableFilterComposer,
      $$GroupsTableOrderingComposer,
      $$GroupsTableAnnotationComposer,
      $$GroupsTableCreateCompanionBuilder,
      $$GroupsTableUpdateCompanionBuilder,
      (Group, $$GroupsTableReferences),
      Group,
      PrefetchHooks Function({bool sessionsRefs})
    >;
typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      required String id,
      Value<int?> characterId,
      Value<String?> groupId,
      Value<String?> name,
      Value<String?> description,
      Value<String> authorNote,
      Value<int> authorNoteDepth,
      Value<String?> parentSession,
      Value<int?> forkIndex,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<String> id,
      Value<int?> characterId,
      Value<String?> groupId,
      Value<String?> name,
      Value<String?> description,
      Value<String> authorNote,
      Value<int> authorNoteDepth,
      Value<String?> parentSession,
      Value<int?> forkIndex,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CharactersTable _characterIdTable(_$AppDatabase db) =>
      db.characters.createAlias(
        $_aliasNameGenerator(db.sessions.characterId, db.characters.id),
      );

  $$CharactersTableProcessedTableManager? get characterId {
    final $_column = $_itemColumn<int>('character_id');
    if ($_column == null) return null;
    final manager = $$CharactersTableTableManager(
      $_db,
      $_db.characters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_characterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $GroupsTable _groupIdTable(_$AppDatabase db) => db.groups.createAlias(
    $_aliasNameGenerator(db.sessions.groupId, db.groups.id),
  );

  $$GroupsTableProcessedTableManager? get groupId {
    final $_column = $_itemColumn<String>('group_id');
    if ($_column == null) return null;
    final manager = $$GroupsTableTableManager(
      $_db,
      $_db.groups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MessagesTable, List<Message>> _messagesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: $_aliasNameGenerator(db.sessions.id, db.messages.sessionId),
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorNote => $composableBuilder(
    column: $table.authorNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get authorNoteDepth => $composableBuilder(
    column: $table.authorNoteDepth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentSession => $composableBuilder(
    column: $table.parentSession,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get forkIndex => $composableBuilder(
    column: $table.forkIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CharactersTableFilterComposer get characterId {
    final $$CharactersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.characterId,
      referencedTable: $db.characters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CharactersTableFilterComposer(
            $db: $db,
            $table: $db.characters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GroupsTableFilterComposer get groupId {
    final $$GroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableFilterComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorNote => $composableBuilder(
    column: $table.authorNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get authorNoteDepth => $composableBuilder(
    column: $table.authorNoteDepth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentSession => $composableBuilder(
    column: $table.parentSession,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get forkIndex => $composableBuilder(
    column: $table.forkIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CharactersTableOrderingComposer get characterId {
    final $$CharactersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.characterId,
      referencedTable: $db.characters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CharactersTableOrderingComposer(
            $db: $db,
            $table: $db.characters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GroupsTableOrderingComposer get groupId {
    final $$GroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableOrderingComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorNote => $composableBuilder(
    column: $table.authorNote,
    builder: (column) => column,
  );

  GeneratedColumn<int> get authorNoteDepth => $composableBuilder(
    column: $table.authorNoteDepth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentSession => $composableBuilder(
    column: $table.parentSession,
    builder: (column) => column,
  );

  GeneratedColumn<int> get forkIndex =>
      $composableBuilder(column: $table.forkIndex, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CharactersTableAnnotationComposer get characterId {
    final $$CharactersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.characterId,
      referencedTable: $db.characters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CharactersTableAnnotationComposer(
            $db: $db,
            $table: $db.characters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GroupsTableAnnotationComposer get groupId {
    final $$GroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, $$SessionsTableReferences),
          Session,
          PrefetchHooks Function({
            bool characterId,
            bool groupId,
            bool messagesRefs,
          })
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> characterId = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> authorNote = const Value.absent(),
                Value<int> authorNoteDepth = const Value.absent(),
                Value<String?> parentSession = const Value.absent(),
                Value<int?> forkIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                characterId: characterId,
                groupId: groupId,
                name: name,
                description: description,
                authorNote: authorNote,
                authorNoteDepth: authorNoteDepth,
                parentSession: parentSession,
                forkIndex: forkIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> characterId = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> authorNote = const Value.absent(),
                Value<int> authorNoteDepth = const Value.absent(),
                Value<String?> parentSession = const Value.absent(),
                Value<int?> forkIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                characterId: characterId,
                groupId: groupId,
                name: name,
                description: description,
                authorNote: authorNote,
                authorNoteDepth: authorNoteDepth,
                parentSession: parentSession,
                forkIndex: forkIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({characterId = false, groupId = false, messagesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (messagesRefs) db.messages],
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
                        if (characterId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.characterId,
                                    referencedTable: $$SessionsTableReferences
                                        ._characterIdTable(db),
                                    referencedColumn: $$SessionsTableReferences
                                        ._characterIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (groupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.groupId,
                                    referencedTable: $$SessionsTableReferences
                                        ._groupIdTable(db),
                                    referencedColumn: $$SessionsTableReferences
                                        ._groupIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (messagesRefs)
                        await $_getPrefetchedData<
                          Session,
                          $SessionsTable,
                          Message
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._messagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).messagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, $$SessionsTableReferences),
      Session,
      PrefetchHooks Function({
        bool characterId,
        bool groupId,
        bool messagesRefs,
      })
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      Value<int> id,
      required String sessionId,
      required int position,
      required String sender,
      required bool isUser,
      Value<String?> characterId,
      Value<String> swipes,
      Value<int> swipeIndex,
      Value<String> swipeDurations,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<int> id,
      Value<String> sessionId,
      Value<int> position,
      Value<String> sender,
      Value<bool> isUser,
      Value<String?> characterId,
      Value<String> swipes,
      Value<int> swipeIndex,
      Value<String> swipeDurations,
    });

final class $$MessagesTableReferences
    extends BaseReferences<_$AppDatabase, $MessagesTable, Message> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) => db.sessions
      .createAlias($_aliasNameGenerator(db.messages.sessionId, db.sessions.id));

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
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

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUser => $composableBuilder(
    column: $table.isUser,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get swipes => $composableBuilder(
    column: $table.swipes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get swipeIndex => $composableBuilder(
    column: $table.swipeIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get swipeDurations => $composableBuilder(
    column: $table.swipeDurations,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
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

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUser => $composableBuilder(
    column: $table.isUser,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get swipes => $composableBuilder(
    column: $table.swipes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get swipeIndex => $composableBuilder(
    column: $table.swipeIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get swipeDurations => $composableBuilder(
    column: $table.swipeDurations,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get sender =>
      $composableBuilder(column: $table.sender, builder: (column) => column);

  GeneratedColumn<bool> get isUser =>
      $composableBuilder(column: $table.isUser, builder: (column) => column);

  GeneratedColumn<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get swipes =>
      $composableBuilder(column: $table.swipes, builder: (column) => column);

  GeneratedColumn<int> get swipeIndex => $composableBuilder(
    column: $table.swipeIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get swipeDurations => $composableBuilder(
    column: $table.swipeDurations,
    builder: (column) => column,
  );

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, $$MessagesTableReferences),
          Message,
          PrefetchHooks Function({bool sessionId})
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> sender = const Value.absent(),
                Value<bool> isUser = const Value.absent(),
                Value<String?> characterId = const Value.absent(),
                Value<String> swipes = const Value.absent(),
                Value<int> swipeIndex = const Value.absent(),
                Value<String> swipeDurations = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                sessionId: sessionId,
                position: position,
                sender: sender,
                isUser: isUser,
                characterId: characterId,
                swipes: swipes,
                swipeIndex: swipeIndex,
                swipeDurations: swipeDurations,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sessionId,
                required int position,
                required String sender,
                required bool isUser,
                Value<String?> characterId = const Value.absent(),
                Value<String> swipes = const Value.absent(),
                Value<int> swipeIndex = const Value.absent(),
                Value<String> swipeDurations = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                sessionId: sessionId,
                position: position,
                sender: sender,
                isUser: isUser,
                characterId: characterId,
                swipes: swipes,
                swipeIndex: swipeIndex,
                swipeDurations: swipeDurations,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
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
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$MessagesTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$MessagesTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, $$MessagesTableReferences),
      Message,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$PersonasTableCreateCompanionBuilder =
    PersonasCompanion Function({
      required String id,
      Value<String> title,
      Value<String> name,
      Value<String> description,
      Value<String> persona,
      Value<String?> avatarPath,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $$PersonasTableUpdateCompanionBuilder =
    PersonasCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> name,
      Value<String> description,
      Value<String> persona,
      Value<String?> avatarPath,
      Value<bool> isActive,
      Value<int> rowid,
    });

class $$PersonasTableFilterComposer
    extends Composer<_$AppDatabase, $PersonasTable> {
  $$PersonasTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get persona => $composableBuilder(
    column: $table.persona,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PersonasTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonasTable> {
  $$PersonasTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get persona => $composableBuilder(
    column: $table.persona,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PersonasTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonasTable> {
  $$PersonasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get persona =>
      $composableBuilder(column: $table.persona, builder: (column) => column);

  GeneratedColumn<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$PersonasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonasTable,
          Persona,
          $$PersonasTableFilterComposer,
          $$PersonasTableOrderingComposer,
          $$PersonasTableAnnotationComposer,
          $$PersonasTableCreateCompanionBuilder,
          $$PersonasTableUpdateCompanionBuilder,
          (Persona, BaseReferences<_$AppDatabase, $PersonasTable, Persona>),
          Persona,
          PrefetchHooks Function()
        > {
  $$PersonasTableTableManager(_$AppDatabase db, $PersonasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> persona = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonasCompanion(
                id: id,
                title: title,
                name: name,
                description: description,
                persona: persona,
                avatarPath: avatarPath,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> persona = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonasCompanion.insert(
                id: id,
                title: title,
                name: name,
                description: description,
                persona: persona,
                avatarPath: avatarPath,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PersonasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonasTable,
      Persona,
      $$PersonasTableFilterComposer,
      $$PersonasTableOrderingComposer,
      $$PersonasTableAnnotationComposer,
      $$PersonasTableCreateCompanionBuilder,
      $$PersonasTableUpdateCompanionBuilder,
      (Persona, BaseReferences<_$AppDatabase, $PersonasTable, Persona>),
      Persona,
      PrefetchHooks Function()
    >;
typedef $$WorldsTableCreateCompanionBuilder =
    WorldsCompanion Function({
      Value<int> id,
      required String name,
      Value<String> description,
      Value<String?> lorebook,
      Value<String?> linkedCharacterName,
    });
typedef $$WorldsTableUpdateCompanionBuilder =
    WorldsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> description,
      Value<String?> lorebook,
      Value<String?> linkedCharacterName,
    });

class $$WorldsTableFilterComposer
    extends Composer<_$AppDatabase, $WorldsTable> {
  $$WorldsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lorebook => $composableBuilder(
    column: $table.lorebook,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedCharacterName => $composableBuilder(
    column: $table.linkedCharacterName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorldsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorldsTable> {
  $$WorldsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lorebook => $composableBuilder(
    column: $table.lorebook,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedCharacterName => $composableBuilder(
    column: $table.linkedCharacterName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorldsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorldsTable> {
  $$WorldsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lorebook =>
      $composableBuilder(column: $table.lorebook, builder: (column) => column);

  GeneratedColumn<String> get linkedCharacterName => $composableBuilder(
    column: $table.linkedCharacterName,
    builder: (column) => column,
  );
}

class $$WorldsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorldsTable,
          World,
          $$WorldsTableFilterComposer,
          $$WorldsTableOrderingComposer,
          $$WorldsTableAnnotationComposer,
          $$WorldsTableCreateCompanionBuilder,
          $$WorldsTableUpdateCompanionBuilder,
          (World, BaseReferences<_$AppDatabase, $WorldsTable, World>),
          World,
          PrefetchHooks Function()
        > {
  $$WorldsTableTableManager(_$AppDatabase db, $WorldsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorldsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorldsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorldsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> lorebook = const Value.absent(),
                Value<String?> linkedCharacterName = const Value.absent(),
              }) => WorldsCompanion(
                id: id,
                name: name,
                description: description,
                lorebook: lorebook,
                linkedCharacterName: linkedCharacterName,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> description = const Value.absent(),
                Value<String?> lorebook = const Value.absent(),
                Value<String?> linkedCharacterName = const Value.absent(),
              }) => WorldsCompanion.insert(
                id: id,
                name: name,
                description: description,
                lorebook: lorebook,
                linkedCharacterName: linkedCharacterName,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorldsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorldsTable,
      World,
      $$WorldsTableFilterComposer,
      $$WorldsTableOrderingComposer,
      $$WorldsTableAnnotationComposer,
      $$WorldsTableCreateCompanionBuilder,
      $$WorldsTableUpdateCompanionBuilder,
      (World, BaseReferences<_$AppDatabase, $WorldsTable, World>),
      World,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$CharactersTableTableManager get characters =>
      $$CharactersTableTableManager(_db, _db.characters);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db, _db.groups);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$PersonasTableTableManager get personas =>
      $$PersonasTableTableManager(_db, _db.personas);
  $$WorldsTableTableManager get worlds =>
      $$WorldsTableTableManager(_db, _db.worlds);
}
