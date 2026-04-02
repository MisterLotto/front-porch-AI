// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CharactersTable extends Characters
    with TableInfo<$CharactersTable, Character> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CharactersTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _memorySourcesMeta = const VerificationMeta(
    'memorySources',
  );
  @override
  late final GeneratedColumn<String> memorySources = GeneratedColumn<String>(
    'memory_sources',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _evolvedPersonalityMeta =
      const VerificationMeta('evolvedPersonality');
  @override
  late final GeneratedColumn<String> evolvedPersonality =
      GeneratedColumn<String>(
        'evolved_personality',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _evolvedScenarioMeta = const VerificationMeta(
    'evolvedScenario',
  );
  @override
  late final GeneratedColumn<String> evolvedScenario = GeneratedColumn<String>(
    'evolved_scenario',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _evolutionCountMeta = const VerificationMeta(
    'evolutionCount',
  );
  @override
  late final GeneratedColumn<int> evolutionCount = GeneratedColumn<int>(
    'evolution_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    memorySources,
    evolvedPersonality,
    evolvedScenario,
    evolutionCount,
    createdAt,
    updatedAt,
    deletedAt,
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
    if (data.containsKey('memory_sources')) {
      context.handle(
        _memorySourcesMeta,
        memorySources.isAcceptableOrUnknown(
          data['memory_sources']!,
          _memorySourcesMeta,
        ),
      );
    }
    if (data.containsKey('evolved_personality')) {
      context.handle(
        _evolvedPersonalityMeta,
        evolvedPersonality.isAcceptableOrUnknown(
          data['evolved_personality']!,
          _evolvedPersonalityMeta,
        ),
      );
    }
    if (data.containsKey('evolved_scenario')) {
      context.handle(
        _evolvedScenarioMeta,
        evolvedScenario.isAcceptableOrUnknown(
          data['evolved_scenario']!,
          _evolvedScenarioMeta,
        ),
      );
    }
    if (data.containsKey('evolution_count')) {
      context.handle(
        _evolutionCountMeta,
        evolutionCount.isAcceptableOrUnknown(
          data['evolution_count']!,
          _evolutionCountMeta,
        ),
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
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
        DriftSqlType.string,
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
        DriftSqlType.string,
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
      memorySources: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memory_sources'],
      )!,
      evolvedPersonality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evolved_personality'],
      )!,
      evolvedScenario: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evolved_scenario'],
      )!,
      evolutionCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}evolution_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CharactersTable createAlias(String alias) {
    return $CharactersTable(attachedDatabase, alias);
  }
}

class Character extends DataClass implements Insertable<Character> {
  final String id;
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
  final String? folderId;
  final String? lorebook;
  final String worldNames;
  final String memorySources;
  final String evolvedPersonality;
  final String evolvedScenario;
  final int evolutionCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
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
    required this.memorySources,
    required this.evolvedPersonality,
    required this.evolvedScenario,
    required this.evolutionCount,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
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
      map['folder_id'] = Variable<String>(folderId);
    }
    if (!nullToAbsent || lorebook != null) {
      map['lorebook'] = Variable<String>(lorebook);
    }
    map['world_names'] = Variable<String>(worldNames);
    map['memory_sources'] = Variable<String>(memorySources);
    map['evolved_personality'] = Variable<String>(evolvedPersonality);
    map['evolved_scenario'] = Variable<String>(evolvedScenario);
    map['evolution_count'] = Variable<int>(evolutionCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
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
      memorySources: Value(memorySources),
      evolvedPersonality: Value(evolvedPersonality),
      evolvedScenario: Value(evolvedScenario),
      evolutionCount: Value(evolutionCount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Character.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Character(
      id: serializer.fromJson<String>(json['id']),
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
      folderId: serializer.fromJson<String?>(json['folderId']),
      lorebook: serializer.fromJson<String?>(json['lorebook']),
      worldNames: serializer.fromJson<String>(json['worldNames']),
      memorySources: serializer.fromJson<String>(json['memorySources']),
      evolvedPersonality: serializer.fromJson<String>(
        json['evolvedPersonality'],
      ),
      evolvedScenario: serializer.fromJson<String>(json['evolvedScenario']),
      evolutionCount: serializer.fromJson<int>(json['evolutionCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
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
      'folderId': serializer.toJson<String?>(folderId),
      'lorebook': serializer.toJson<String?>(lorebook),
      'worldNames': serializer.toJson<String>(worldNames),
      'memorySources': serializer.toJson<String>(memorySources),
      'evolvedPersonality': serializer.toJson<String>(evolvedPersonality),
      'evolvedScenario': serializer.toJson<String>(evolvedScenario),
      'evolutionCount': serializer.toJson<int>(evolutionCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Character copyWith({
    String? id,
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
    Value<String?> folderId = const Value.absent(),
    Value<String?> lorebook = const Value.absent(),
    String? worldNames,
    String? memorySources,
    String? evolvedPersonality,
    String? evolvedScenario,
    int? evolutionCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
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
    memorySources: memorySources ?? this.memorySources,
    evolvedPersonality: evolvedPersonality ?? this.evolvedPersonality,
    evolvedScenario: evolvedScenario ?? this.evolvedScenario,
    evolutionCount: evolutionCount ?? this.evolutionCount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
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
      memorySources: data.memorySources.present
          ? data.memorySources.value
          : this.memorySources,
      evolvedPersonality: data.evolvedPersonality.present
          ? data.evolvedPersonality.value
          : this.evolvedPersonality,
      evolvedScenario: data.evolvedScenario.present
          ? data.evolvedScenario.value
          : this.evolvedScenario,
      evolutionCount: data.evolutionCount.present
          ? data.evolutionCount.value
          : this.evolutionCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
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
          ..write('memorySources: $memorySources, ')
          ..write('evolvedPersonality: $evolvedPersonality, ')
          ..write('evolvedScenario: $evolvedScenario, ')
          ..write('evolutionCount: $evolutionCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
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
    memorySources,
    evolvedPersonality,
    evolvedScenario,
    evolutionCount,
    createdAt,
    updatedAt,
    deletedAt,
  ]);
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
          other.memorySources == this.memorySources &&
          other.evolvedPersonality == this.evolvedPersonality &&
          other.evolvedScenario == this.evolvedScenario &&
          other.evolutionCount == this.evolutionCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CharactersCompanion extends UpdateCompanion<Character> {
  final Value<String> id;
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
  final Value<String?> folderId;
  final Value<String?> lorebook;
  final Value<String> worldNames;
  final Value<String> memorySources;
  final Value<String> evolvedPersonality;
  final Value<String> evolvedScenario;
  final Value<int> evolutionCount;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
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
    this.memorySources = const Value.absent(),
    this.evolvedPersonality = const Value.absent(),
    this.evolvedScenario = const Value.absent(),
    this.evolutionCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CharactersCompanion.insert({
    required String id,
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
    this.memorySources = const Value.absent(),
    this.evolvedPersonality = const Value.absent(),
    this.evolvedScenario = const Value.absent(),
    this.evolutionCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Character> custom({
    Expression<String>? id,
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
    Expression<String>? folderId,
    Expression<String>? lorebook,
    Expression<String>? worldNames,
    Expression<String>? memorySources,
    Expression<String>? evolvedPersonality,
    Expression<String>? evolvedScenario,
    Expression<int>? evolutionCount,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
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
      if (memorySources != null) 'memory_sources': memorySources,
      if (evolvedPersonality != null) 'evolved_personality': evolvedPersonality,
      if (evolvedScenario != null) 'evolved_scenario': evolvedScenario,
      if (evolutionCount != null) 'evolution_count': evolutionCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CharactersCompanion copyWith({
    Value<String>? id,
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
    Value<String?>? folderId,
    Value<String?>? lorebook,
    Value<String>? worldNames,
    Value<String>? memorySources,
    Value<String>? evolvedPersonality,
    Value<String>? evolvedScenario,
    Value<int>? evolutionCount,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
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
      memorySources: memorySources ?? this.memorySources,
      evolvedPersonality: evolvedPersonality ?? this.evolvedPersonality,
      evolvedScenario: evolvedScenario ?? this.evolvedScenario,
      evolutionCount: evolutionCount ?? this.evolutionCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
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
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (lorebook.present) {
      map['lorebook'] = Variable<String>(lorebook.value);
    }
    if (worldNames.present) {
      map['world_names'] = Variable<String>(worldNames.value);
    }
    if (memorySources.present) {
      map['memory_sources'] = Variable<String>(memorySources.value);
    }
    if (evolvedPersonality.present) {
      map['evolved_personality'] = Variable<String>(evolvedPersonality.value);
    }
    if (evolvedScenario.present) {
      map['evolved_scenario'] = Variable<String>(evolvedScenario.value);
    }
    if (evolutionCount.present) {
      map['evolution_count'] = Variable<int>(evolutionCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
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
          ..write('memorySources: $memorySources, ')
          ..write('evolvedPersonality: $evolvedPersonality, ')
          ..write('evolvedScenario: $evolvedScenario, ')
          ..write('evolutionCount: $evolutionCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
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
  late final GeneratedColumn<String> characterId = GeneratedColumn<String>(
    'character_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryLastIndexMeta = const VerificationMeta(
    'summaryLastIndex',
  );
  @override
  late final GeneratedColumn<int> summaryLastIndex = GeneratedColumn<int>(
    'summary_last_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _affectionScoreMeta = const VerificationMeta(
    'affectionScore',
  );
  @override
  late final GeneratedColumn<int> affectionScore = GeneratedColumn<int>(
    'affection_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _relationshipTierMeta = const VerificationMeta(
    'relationshipTier',
  );
  @override
  late final GeneratedColumn<int> relationshipTier = GeneratedColumn<int>(
    'relationship_tier',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _realismEnabledMeta = const VerificationMeta(
    'realismEnabled',
  );
  @override
  late final GeneratedColumn<bool> realismEnabled = GeneratedColumn<bool>(
    'realism_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("realism_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _shortTermMoodMeta = const VerificationMeta(
    'shortTermMood',
  );
  @override
  late final GeneratedColumn<int> shortTermMood = GeneratedColumn<int>(
    'short_term_mood',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _moodDecayCounterMeta = const VerificationMeta(
    'moodDecayCounter',
  );
  @override
  late final GeneratedColumn<int> moodDecayCounter = GeneratedColumn<int>(
    'mood_decay_counter',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _characterEmotionMeta = const VerificationMeta(
    'characterEmotion',
  );
  @override
  late final GeneratedColumn<String> characterEmotion = GeneratedColumn<String>(
    'character_emotion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _emotionIntensityMeta = const VerificationMeta(
    'emotionIntensity',
  );
  @override
  late final GeneratedColumn<String> emotionIntensity = GeneratedColumn<String>(
    'emotion_intensity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _timeOfDayMeta = const VerificationMeta(
    'timeOfDay',
  );
  @override
  late final GeneratedColumn<String> timeOfDay = GeneratedColumn<String>(
    'time_of_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('morning'),
  );
  static const VerificationMeta _dayCountMeta = const VerificationMeta(
    'dayCount',
  );
  @override
  late final GeneratedColumn<int> dayCount = GeneratedColumn<int>(
    'day_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _nsfwCooldownEnabledMeta =
      const VerificationMeta('nsfwCooldownEnabled');
  @override
  late final GeneratedColumn<bool> nsfwCooldownEnabled = GeneratedColumn<bool>(
    'nsfw_cooldown_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("nsfw_cooldown_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _arousalLevelMeta = const VerificationMeta(
    'arousalLevel',
  );
  @override
  late final GeneratedColumn<int> arousalLevel = GeneratedColumn<int>(
    'arousal_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cooldownTurnsRemainingMeta =
      const VerificationMeta('cooldownTurnsRemaining');
  @override
  late final GeneratedColumn<int> cooldownTurnsRemaining = GeneratedColumn<int>(
    'cooldown_turns_remaining',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    summary,
    summaryLastIndex,
    parentSession,
    forkIndex,
    affectionScore,
    relationshipTier,
    realismEnabled,
    shortTermMood,
    moodDecayCounter,
    characterEmotion,
    emotionIntensity,
    timeOfDay,
    dayCount,
    nsfwCooldownEnabled,
    arousalLevel,
    cooldownTurnsRemaining,
    createdAt,
    updatedAt,
    deletedAt,
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
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('summary_last_index')) {
      context.handle(
        _summaryLastIndexMeta,
        summaryLastIndex.isAcceptableOrUnknown(
          data['summary_last_index']!,
          _summaryLastIndexMeta,
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
    if (data.containsKey('affection_score')) {
      context.handle(
        _affectionScoreMeta,
        affectionScore.isAcceptableOrUnknown(
          data['affection_score']!,
          _affectionScoreMeta,
        ),
      );
    }
    if (data.containsKey('relationship_tier')) {
      context.handle(
        _relationshipTierMeta,
        relationshipTier.isAcceptableOrUnknown(
          data['relationship_tier']!,
          _relationshipTierMeta,
        ),
      );
    }
    if (data.containsKey('realism_enabled')) {
      context.handle(
        _realismEnabledMeta,
        realismEnabled.isAcceptableOrUnknown(
          data['realism_enabled']!,
          _realismEnabledMeta,
        ),
      );
    }
    if (data.containsKey('short_term_mood')) {
      context.handle(
        _shortTermMoodMeta,
        shortTermMood.isAcceptableOrUnknown(
          data['short_term_mood']!,
          _shortTermMoodMeta,
        ),
      );
    }
    if (data.containsKey('mood_decay_counter')) {
      context.handle(
        _moodDecayCounterMeta,
        moodDecayCounter.isAcceptableOrUnknown(
          data['mood_decay_counter']!,
          _moodDecayCounterMeta,
        ),
      );
    }
    if (data.containsKey('character_emotion')) {
      context.handle(
        _characterEmotionMeta,
        characterEmotion.isAcceptableOrUnknown(
          data['character_emotion']!,
          _characterEmotionMeta,
        ),
      );
    }
    if (data.containsKey('emotion_intensity')) {
      context.handle(
        _emotionIntensityMeta,
        emotionIntensity.isAcceptableOrUnknown(
          data['emotion_intensity']!,
          _emotionIntensityMeta,
        ),
      );
    }
    if (data.containsKey('time_of_day')) {
      context.handle(
        _timeOfDayMeta,
        timeOfDay.isAcceptableOrUnknown(data['time_of_day']!, _timeOfDayMeta),
      );
    }
    if (data.containsKey('day_count')) {
      context.handle(
        _dayCountMeta,
        dayCount.isAcceptableOrUnknown(data['day_count']!, _dayCountMeta),
      );
    }
    if (data.containsKey('nsfw_cooldown_enabled')) {
      context.handle(
        _nsfwCooldownEnabledMeta,
        nsfwCooldownEnabled.isAcceptableOrUnknown(
          data['nsfw_cooldown_enabled']!,
          _nsfwCooldownEnabledMeta,
        ),
      );
    }
    if (data.containsKey('arousal_level')) {
      context.handle(
        _arousalLevelMeta,
        arousalLevel.isAcceptableOrUnknown(
          data['arousal_level']!,
          _arousalLevelMeta,
        ),
      );
    }
    if (data.containsKey('cooldown_turns_remaining')) {
      context.handle(
        _cooldownTurnsRemainingMeta,
        cooldownTurnsRemaining.isAcceptableOrUnknown(
          data['cooldown_turns_remaining']!,
          _cooldownTurnsRemainingMeta,
        ),
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
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
        DriftSqlType.string,
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
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      summaryLastIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}summary_last_index'],
      ),
      parentSession: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_session'],
      ),
      forkIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fork_index'],
      ),
      affectionScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}affection_score'],
      )!,
      relationshipTier: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}relationship_tier'],
      )!,
      realismEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}realism_enabled'],
      )!,
      shortTermMood: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}short_term_mood'],
      )!,
      moodDecayCounter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mood_decay_counter'],
      )!,
      characterEmotion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_emotion'],
      )!,
      emotionIntensity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emotion_intensity'],
      )!,
      timeOfDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_of_day'],
      )!,
      dayCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_count'],
      )!,
      nsfwCooldownEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}nsfw_cooldown_enabled'],
      )!,
      arousalLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}arousal_level'],
      )!,
      cooldownTurnsRemaining: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cooldown_turns_remaining'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final String id;
  final String? characterId;
  final String? groupId;
  final String? name;
  final String? description;
  final String authorNote;
  final int authorNoteDepth;
  final String? summary;
  final int? summaryLastIndex;
  final String? parentSession;
  final int? forkIndex;
  final int affectionScore;
  final int relationshipTier;
  final bool realismEnabled;
  final int shortTermMood;
  final int moodDecayCounter;
  final String characterEmotion;
  final String emotionIntensity;
  final String timeOfDay;
  final int dayCount;
  final bool nsfwCooldownEnabled;
  final int arousalLevel;
  final int cooldownTurnsRemaining;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Session({
    required this.id,
    this.characterId,
    this.groupId,
    this.name,
    this.description,
    required this.authorNote,
    required this.authorNoteDepth,
    this.summary,
    this.summaryLastIndex,
    this.parentSession,
    this.forkIndex,
    required this.affectionScore,
    required this.relationshipTier,
    required this.realismEnabled,
    required this.shortTermMood,
    required this.moodDecayCounter,
    required this.characterEmotion,
    required this.emotionIntensity,
    required this.timeOfDay,
    required this.dayCount,
    required this.nsfwCooldownEnabled,
    required this.arousalLevel,
    required this.cooldownTurnsRemaining,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || characterId != null) {
      map['character_id'] = Variable<String>(characterId);
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
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || summaryLastIndex != null) {
      map['summary_last_index'] = Variable<int>(summaryLastIndex);
    }
    if (!nullToAbsent || parentSession != null) {
      map['parent_session'] = Variable<String>(parentSession);
    }
    if (!nullToAbsent || forkIndex != null) {
      map['fork_index'] = Variable<int>(forkIndex);
    }
    map['affection_score'] = Variable<int>(affectionScore);
    map['relationship_tier'] = Variable<int>(relationshipTier);
    map['realism_enabled'] = Variable<bool>(realismEnabled);
    map['short_term_mood'] = Variable<int>(shortTermMood);
    map['mood_decay_counter'] = Variable<int>(moodDecayCounter);
    map['character_emotion'] = Variable<String>(characterEmotion);
    map['emotion_intensity'] = Variable<String>(emotionIntensity);
    map['time_of_day'] = Variable<String>(timeOfDay);
    map['day_count'] = Variable<int>(dayCount);
    map['nsfw_cooldown_enabled'] = Variable<bool>(nsfwCooldownEnabled);
    map['arousal_level'] = Variable<int>(arousalLevel);
    map['cooldown_turns_remaining'] = Variable<int>(cooldownTurnsRemaining);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
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
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      summaryLastIndex: summaryLastIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryLastIndex),
      parentSession: parentSession == null && nullToAbsent
          ? const Value.absent()
          : Value(parentSession),
      forkIndex: forkIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(forkIndex),
      affectionScore: Value(affectionScore),
      relationshipTier: Value(relationshipTier),
      realismEnabled: Value(realismEnabled),
      shortTermMood: Value(shortTermMood),
      moodDecayCounter: Value(moodDecayCounter),
      characterEmotion: Value(characterEmotion),
      emotionIntensity: Value(emotionIntensity),
      timeOfDay: Value(timeOfDay),
      dayCount: Value(dayCount),
      nsfwCooldownEnabled: Value(nsfwCooldownEnabled),
      arousalLevel: Value(arousalLevel),
      cooldownTurnsRemaining: Value(cooldownTurnsRemaining),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      characterId: serializer.fromJson<String?>(json['characterId']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      name: serializer.fromJson<String?>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      authorNote: serializer.fromJson<String>(json['authorNote']),
      authorNoteDepth: serializer.fromJson<int>(json['authorNoteDepth']),
      summary: serializer.fromJson<String?>(json['summary']),
      summaryLastIndex: serializer.fromJson<int?>(json['summaryLastIndex']),
      parentSession: serializer.fromJson<String?>(json['parentSession']),
      forkIndex: serializer.fromJson<int?>(json['forkIndex']),
      affectionScore: serializer.fromJson<int>(json['affectionScore']),
      relationshipTier: serializer.fromJson<int>(json['relationshipTier']),
      realismEnabled: serializer.fromJson<bool>(json['realismEnabled']),
      shortTermMood: serializer.fromJson<int>(json['shortTermMood']),
      moodDecayCounter: serializer.fromJson<int>(json['moodDecayCounter']),
      characterEmotion: serializer.fromJson<String>(json['characterEmotion']),
      emotionIntensity: serializer.fromJson<String>(json['emotionIntensity']),
      timeOfDay: serializer.fromJson<String>(json['timeOfDay']),
      dayCount: serializer.fromJson<int>(json['dayCount']),
      nsfwCooldownEnabled: serializer.fromJson<bool>(
        json['nsfwCooldownEnabled'],
      ),
      arousalLevel: serializer.fromJson<int>(json['arousalLevel']),
      cooldownTurnsRemaining: serializer.fromJson<int>(
        json['cooldownTurnsRemaining'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'characterId': serializer.toJson<String?>(characterId),
      'groupId': serializer.toJson<String?>(groupId),
      'name': serializer.toJson<String?>(name),
      'description': serializer.toJson<String?>(description),
      'authorNote': serializer.toJson<String>(authorNote),
      'authorNoteDepth': serializer.toJson<int>(authorNoteDepth),
      'summary': serializer.toJson<String?>(summary),
      'summaryLastIndex': serializer.toJson<int?>(summaryLastIndex),
      'parentSession': serializer.toJson<String?>(parentSession),
      'forkIndex': serializer.toJson<int?>(forkIndex),
      'affectionScore': serializer.toJson<int>(affectionScore),
      'relationshipTier': serializer.toJson<int>(relationshipTier),
      'realismEnabled': serializer.toJson<bool>(realismEnabled),
      'shortTermMood': serializer.toJson<int>(shortTermMood),
      'moodDecayCounter': serializer.toJson<int>(moodDecayCounter),
      'characterEmotion': serializer.toJson<String>(characterEmotion),
      'emotionIntensity': serializer.toJson<String>(emotionIntensity),
      'timeOfDay': serializer.toJson<String>(timeOfDay),
      'dayCount': serializer.toJson<int>(dayCount),
      'nsfwCooldownEnabled': serializer.toJson<bool>(nsfwCooldownEnabled),
      'arousalLevel': serializer.toJson<int>(arousalLevel),
      'cooldownTurnsRemaining': serializer.toJson<int>(cooldownTurnsRemaining),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Session copyWith({
    String? id,
    Value<String?> characterId = const Value.absent(),
    Value<String?> groupId = const Value.absent(),
    Value<String?> name = const Value.absent(),
    Value<String?> description = const Value.absent(),
    String? authorNote,
    int? authorNoteDepth,
    Value<String?> summary = const Value.absent(),
    Value<int?> summaryLastIndex = const Value.absent(),
    Value<String?> parentSession = const Value.absent(),
    Value<int?> forkIndex = const Value.absent(),
    int? affectionScore,
    int? relationshipTier,
    bool? realismEnabled,
    int? shortTermMood,
    int? moodDecayCounter,
    String? characterEmotion,
    String? emotionIntensity,
    String? timeOfDay,
    int? dayCount,
    bool? nsfwCooldownEnabled,
    int? arousalLevel,
    int? cooldownTurnsRemaining,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Session(
    id: id ?? this.id,
    characterId: characterId.present ? characterId.value : this.characterId,
    groupId: groupId.present ? groupId.value : this.groupId,
    name: name.present ? name.value : this.name,
    description: description.present ? description.value : this.description,
    authorNote: authorNote ?? this.authorNote,
    authorNoteDepth: authorNoteDepth ?? this.authorNoteDepth,
    summary: summary.present ? summary.value : this.summary,
    summaryLastIndex: summaryLastIndex.present
        ? summaryLastIndex.value
        : this.summaryLastIndex,
    parentSession: parentSession.present
        ? parentSession.value
        : this.parentSession,
    forkIndex: forkIndex.present ? forkIndex.value : this.forkIndex,
    affectionScore: affectionScore ?? this.affectionScore,
    relationshipTier: relationshipTier ?? this.relationshipTier,
    realismEnabled: realismEnabled ?? this.realismEnabled,
    shortTermMood: shortTermMood ?? this.shortTermMood,
    moodDecayCounter: moodDecayCounter ?? this.moodDecayCounter,
    characterEmotion: characterEmotion ?? this.characterEmotion,
    emotionIntensity: emotionIntensity ?? this.emotionIntensity,
    timeOfDay: timeOfDay ?? this.timeOfDay,
    dayCount: dayCount ?? this.dayCount,
    nsfwCooldownEnabled: nsfwCooldownEnabled ?? this.nsfwCooldownEnabled,
    arousalLevel: arousalLevel ?? this.arousalLevel,
    cooldownTurnsRemaining:
        cooldownTurnsRemaining ?? this.cooldownTurnsRemaining,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
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
      summary: data.summary.present ? data.summary.value : this.summary,
      summaryLastIndex: data.summaryLastIndex.present
          ? data.summaryLastIndex.value
          : this.summaryLastIndex,
      parentSession: data.parentSession.present
          ? data.parentSession.value
          : this.parentSession,
      forkIndex: data.forkIndex.present ? data.forkIndex.value : this.forkIndex,
      affectionScore: data.affectionScore.present
          ? data.affectionScore.value
          : this.affectionScore,
      relationshipTier: data.relationshipTier.present
          ? data.relationshipTier.value
          : this.relationshipTier,
      realismEnabled: data.realismEnabled.present
          ? data.realismEnabled.value
          : this.realismEnabled,
      shortTermMood: data.shortTermMood.present
          ? data.shortTermMood.value
          : this.shortTermMood,
      moodDecayCounter: data.moodDecayCounter.present
          ? data.moodDecayCounter.value
          : this.moodDecayCounter,
      characterEmotion: data.characterEmotion.present
          ? data.characterEmotion.value
          : this.characterEmotion,
      emotionIntensity: data.emotionIntensity.present
          ? data.emotionIntensity.value
          : this.emotionIntensity,
      timeOfDay: data.timeOfDay.present ? data.timeOfDay.value : this.timeOfDay,
      dayCount: data.dayCount.present ? data.dayCount.value : this.dayCount,
      nsfwCooldownEnabled: data.nsfwCooldownEnabled.present
          ? data.nsfwCooldownEnabled.value
          : this.nsfwCooldownEnabled,
      arousalLevel: data.arousalLevel.present
          ? data.arousalLevel.value
          : this.arousalLevel,
      cooldownTurnsRemaining: data.cooldownTurnsRemaining.present
          ? data.cooldownTurnsRemaining.value
          : this.cooldownTurnsRemaining,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
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
          ..write('summary: $summary, ')
          ..write('summaryLastIndex: $summaryLastIndex, ')
          ..write('parentSession: $parentSession, ')
          ..write('forkIndex: $forkIndex, ')
          ..write('affectionScore: $affectionScore, ')
          ..write('relationshipTier: $relationshipTier, ')
          ..write('realismEnabled: $realismEnabled, ')
          ..write('shortTermMood: $shortTermMood, ')
          ..write('moodDecayCounter: $moodDecayCounter, ')
          ..write('characterEmotion: $characterEmotion, ')
          ..write('emotionIntensity: $emotionIntensity, ')
          ..write('timeOfDay: $timeOfDay, ')
          ..write('dayCount: $dayCount, ')
          ..write('nsfwCooldownEnabled: $nsfwCooldownEnabled, ')
          ..write('arousalLevel: $arousalLevel, ')
          ..write('cooldownTurnsRemaining: $cooldownTurnsRemaining, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    characterId,
    groupId,
    name,
    description,
    authorNote,
    authorNoteDepth,
    summary,
    summaryLastIndex,
    parentSession,
    forkIndex,
    affectionScore,
    relationshipTier,
    realismEnabled,
    shortTermMood,
    moodDecayCounter,
    characterEmotion,
    emotionIntensity,
    timeOfDay,
    dayCount,
    nsfwCooldownEnabled,
    arousalLevel,
    cooldownTurnsRemaining,
    createdAt,
    updatedAt,
    deletedAt,
  ]);
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
          other.summary == this.summary &&
          other.summaryLastIndex == this.summaryLastIndex &&
          other.parentSession == this.parentSession &&
          other.forkIndex == this.forkIndex &&
          other.affectionScore == this.affectionScore &&
          other.relationshipTier == this.relationshipTier &&
          other.realismEnabled == this.realismEnabled &&
          other.shortTermMood == this.shortTermMood &&
          other.moodDecayCounter == this.moodDecayCounter &&
          other.characterEmotion == this.characterEmotion &&
          other.emotionIntensity == this.emotionIntensity &&
          other.timeOfDay == this.timeOfDay &&
          other.dayCount == this.dayCount &&
          other.nsfwCooldownEnabled == this.nsfwCooldownEnabled &&
          other.arousalLevel == this.arousalLevel &&
          other.cooldownTurnsRemaining == this.cooldownTurnsRemaining &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<String?> characterId;
  final Value<String?> groupId;
  final Value<String?> name;
  final Value<String?> description;
  final Value<String> authorNote;
  final Value<int> authorNoteDepth;
  final Value<String?> summary;
  final Value<int?> summaryLastIndex;
  final Value<String?> parentSession;
  final Value<int?> forkIndex;
  final Value<int> affectionScore;
  final Value<int> relationshipTier;
  final Value<bool> realismEnabled;
  final Value<int> shortTermMood;
  final Value<int> moodDecayCounter;
  final Value<String> characterEmotion;
  final Value<String> emotionIntensity;
  final Value<String> timeOfDay;
  final Value<int> dayCount;
  final Value<bool> nsfwCooldownEnabled;
  final Value<int> arousalLevel;
  final Value<int> cooldownTurnsRemaining;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.characterId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.authorNote = const Value.absent(),
    this.authorNoteDepth = const Value.absent(),
    this.summary = const Value.absent(),
    this.summaryLastIndex = const Value.absent(),
    this.parentSession = const Value.absent(),
    this.forkIndex = const Value.absent(),
    this.affectionScore = const Value.absent(),
    this.relationshipTier = const Value.absent(),
    this.realismEnabled = const Value.absent(),
    this.shortTermMood = const Value.absent(),
    this.moodDecayCounter = const Value.absent(),
    this.characterEmotion = const Value.absent(),
    this.emotionIntensity = const Value.absent(),
    this.timeOfDay = const Value.absent(),
    this.dayCount = const Value.absent(),
    this.nsfwCooldownEnabled = const Value.absent(),
    this.arousalLevel = const Value.absent(),
    this.cooldownTurnsRemaining = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
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
    this.summary = const Value.absent(),
    this.summaryLastIndex = const Value.absent(),
    this.parentSession = const Value.absent(),
    this.forkIndex = const Value.absent(),
    this.affectionScore = const Value.absent(),
    this.relationshipTier = const Value.absent(),
    this.realismEnabled = const Value.absent(),
    this.shortTermMood = const Value.absent(),
    this.moodDecayCounter = const Value.absent(),
    this.characterEmotion = const Value.absent(),
    this.emotionIntensity = const Value.absent(),
    this.timeOfDay = const Value.absent(),
    this.dayCount = const Value.absent(),
    this.nsfwCooldownEnabled = const Value.absent(),
    this.arousalLevel = const Value.absent(),
    this.cooldownTurnsRemaining = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<String>? characterId,
    Expression<String>? groupId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? authorNote,
    Expression<int>? authorNoteDepth,
    Expression<String>? summary,
    Expression<int>? summaryLastIndex,
    Expression<String>? parentSession,
    Expression<int>? forkIndex,
    Expression<int>? affectionScore,
    Expression<int>? relationshipTier,
    Expression<bool>? realismEnabled,
    Expression<int>? shortTermMood,
    Expression<int>? moodDecayCounter,
    Expression<String>? characterEmotion,
    Expression<String>? emotionIntensity,
    Expression<String>? timeOfDay,
    Expression<int>? dayCount,
    Expression<bool>? nsfwCooldownEnabled,
    Expression<int>? arousalLevel,
    Expression<int>? cooldownTurnsRemaining,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
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
      if (summary != null) 'summary': summary,
      if (summaryLastIndex != null) 'summary_last_index': summaryLastIndex,
      if (parentSession != null) 'parent_session': parentSession,
      if (forkIndex != null) 'fork_index': forkIndex,
      if (affectionScore != null) 'affection_score': affectionScore,
      if (relationshipTier != null) 'relationship_tier': relationshipTier,
      if (realismEnabled != null) 'realism_enabled': realismEnabled,
      if (shortTermMood != null) 'short_term_mood': shortTermMood,
      if (moodDecayCounter != null) 'mood_decay_counter': moodDecayCounter,
      if (characterEmotion != null) 'character_emotion': characterEmotion,
      if (emotionIntensity != null) 'emotion_intensity': emotionIntensity,
      if (timeOfDay != null) 'time_of_day': timeOfDay,
      if (dayCount != null) 'day_count': dayCount,
      if (nsfwCooldownEnabled != null)
        'nsfw_cooldown_enabled': nsfwCooldownEnabled,
      if (arousalLevel != null) 'arousal_level': arousalLevel,
      if (cooldownTurnsRemaining != null)
        'cooldown_turns_remaining': cooldownTurnsRemaining,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? characterId,
    Value<String?>? groupId,
    Value<String?>? name,
    Value<String?>? description,
    Value<String>? authorNote,
    Value<int>? authorNoteDepth,
    Value<String?>? summary,
    Value<int?>? summaryLastIndex,
    Value<String?>? parentSession,
    Value<int?>? forkIndex,
    Value<int>? affectionScore,
    Value<int>? relationshipTier,
    Value<bool>? realismEnabled,
    Value<int>? shortTermMood,
    Value<int>? moodDecayCounter,
    Value<String>? characterEmotion,
    Value<String>? emotionIntensity,
    Value<String>? timeOfDay,
    Value<int>? dayCount,
    Value<bool>? nsfwCooldownEnabled,
    Value<int>? arousalLevel,
    Value<int>? cooldownTurnsRemaining,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
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
      summary: summary ?? this.summary,
      summaryLastIndex: summaryLastIndex ?? this.summaryLastIndex,
      parentSession: parentSession ?? this.parentSession,
      forkIndex: forkIndex ?? this.forkIndex,
      affectionScore: affectionScore ?? this.affectionScore,
      relationshipTier: relationshipTier ?? this.relationshipTier,
      realismEnabled: realismEnabled ?? this.realismEnabled,
      shortTermMood: shortTermMood ?? this.shortTermMood,
      moodDecayCounter: moodDecayCounter ?? this.moodDecayCounter,
      characterEmotion: characterEmotion ?? this.characterEmotion,
      emotionIntensity: emotionIntensity ?? this.emotionIntensity,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      dayCount: dayCount ?? this.dayCount,
      nsfwCooldownEnabled: nsfwCooldownEnabled ?? this.nsfwCooldownEnabled,
      arousalLevel: arousalLevel ?? this.arousalLevel,
      cooldownTurnsRemaining:
          cooldownTurnsRemaining ?? this.cooldownTurnsRemaining,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
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
      map['character_id'] = Variable<String>(characterId.value);
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
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (summaryLastIndex.present) {
      map['summary_last_index'] = Variable<int>(summaryLastIndex.value);
    }
    if (parentSession.present) {
      map['parent_session'] = Variable<String>(parentSession.value);
    }
    if (forkIndex.present) {
      map['fork_index'] = Variable<int>(forkIndex.value);
    }
    if (affectionScore.present) {
      map['affection_score'] = Variable<int>(affectionScore.value);
    }
    if (relationshipTier.present) {
      map['relationship_tier'] = Variable<int>(relationshipTier.value);
    }
    if (realismEnabled.present) {
      map['realism_enabled'] = Variable<bool>(realismEnabled.value);
    }
    if (shortTermMood.present) {
      map['short_term_mood'] = Variable<int>(shortTermMood.value);
    }
    if (moodDecayCounter.present) {
      map['mood_decay_counter'] = Variable<int>(moodDecayCounter.value);
    }
    if (characterEmotion.present) {
      map['character_emotion'] = Variable<String>(characterEmotion.value);
    }
    if (emotionIntensity.present) {
      map['emotion_intensity'] = Variable<String>(emotionIntensity.value);
    }
    if (timeOfDay.present) {
      map['time_of_day'] = Variable<String>(timeOfDay.value);
    }
    if (dayCount.present) {
      map['day_count'] = Variable<int>(dayCount.value);
    }
    if (nsfwCooldownEnabled.present) {
      map['nsfw_cooldown_enabled'] = Variable<bool>(nsfwCooldownEnabled.value);
    }
    if (arousalLevel.present) {
      map['arousal_level'] = Variable<int>(arousalLevel.value);
    }
    if (cooldownTurnsRemaining.present) {
      map['cooldown_turns_remaining'] = Variable<int>(
        cooldownTurnsRemaining.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
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
          ..write('summary: $summary, ')
          ..write('summaryLastIndex: $summaryLastIndex, ')
          ..write('parentSession: $parentSession, ')
          ..write('forkIndex: $forkIndex, ')
          ..write('affectionScore: $affectionScore, ')
          ..write('relationshipTier: $relationshipTier, ')
          ..write('realismEnabled: $realismEnabled, ')
          ..write('shortTermMood: $shortTermMood, ')
          ..write('moodDecayCounter: $moodDecayCounter, ')
          ..write('characterEmotion: $characterEmotion, ')
          ..write('emotionIntensity: $emotionIntensity, ')
          ..write('timeOfDay: $timeOfDay, ')
          ..write('dayCount: $dayCount, ')
          ..write('nsfwCooldownEnabled: $nsfwCooldownEnabled, ')
          ..write('arousalLevel: $arousalLevel, ')
          ..write('cooldownTurnsRemaining: $cooldownTurnsRemaining, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
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
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _swipeMetadataMeta = const VerificationMeta(
    'swipeMetadata',
  );
  @override
  late final GeneratedColumn<String> swipeMetadata = GeneratedColumn<String>(
    'swipe_metadata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    metadata,
    swipeMetadata,
    updatedAt,
    deletedAt,
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
    } else if (isInserting) {
      context.missing(_idMeta);
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
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    if (data.containsKey('swipe_metadata')) {
      context.handle(
        _swipeMetadataMeta,
        swipeMetadata.isAcceptableOrUnknown(
          data['swipe_metadata']!,
          _swipeMetadataMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
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
        DriftSqlType.string,
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
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      ),
      swipeMetadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}swipe_metadata'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final String id;
  final String sessionId;
  final int position;
  final String sender;
  final bool isUser;
  final String? characterId;
  final String swipes;
  final int swipeIndex;
  final String swipeDurations;
  final String? metadata;
  final String? swipeMetadata;
  final DateTime updatedAt;
  final DateTime? deletedAt;
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
    this.metadata,
    this.swipeMetadata,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
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
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    if (!nullToAbsent || swipeMetadata != null) {
      map['swipe_metadata'] = Variable<String>(swipeMetadata);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
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
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
      swipeMetadata: swipeMetadata == null && nullToAbsent
          ? const Value.absent()
          : Value(swipeMetadata),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      position: serializer.fromJson<int>(json['position']),
      sender: serializer.fromJson<String>(json['sender']),
      isUser: serializer.fromJson<bool>(json['isUser']),
      characterId: serializer.fromJson<String?>(json['characterId']),
      swipes: serializer.fromJson<String>(json['swipes']),
      swipeIndex: serializer.fromJson<int>(json['swipeIndex']),
      swipeDurations: serializer.fromJson<String>(json['swipeDurations']),
      metadata: serializer.fromJson<String?>(json['metadata']),
      swipeMetadata: serializer.fromJson<String?>(json['swipeMetadata']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'position': serializer.toJson<int>(position),
      'sender': serializer.toJson<String>(sender),
      'isUser': serializer.toJson<bool>(isUser),
      'characterId': serializer.toJson<String?>(characterId),
      'swipes': serializer.toJson<String>(swipes),
      'swipeIndex': serializer.toJson<int>(swipeIndex),
      'swipeDurations': serializer.toJson<String>(swipeDurations),
      'metadata': serializer.toJson<String?>(metadata),
      'swipeMetadata': serializer.toJson<String?>(swipeMetadata),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Message copyWith({
    String? id,
    String? sessionId,
    int? position,
    String? sender,
    bool? isUser,
    Value<String?> characterId = const Value.absent(),
    String? swipes,
    int? swipeIndex,
    String? swipeDurations,
    Value<String?> metadata = const Value.absent(),
    Value<String?> swipeMetadata = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
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
    metadata: metadata.present ? metadata.value : this.metadata,
    swipeMetadata: swipeMetadata.present
        ? swipeMetadata.value
        : this.swipeMetadata,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
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
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      swipeMetadata: data.swipeMetadata.present
          ? data.swipeMetadata.value
          : this.swipeMetadata,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
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
          ..write('swipeDurations: $swipeDurations, ')
          ..write('metadata: $metadata, ')
          ..write('swipeMetadata: $swipeMetadata, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
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
    metadata,
    swipeMetadata,
    updatedAt,
    deletedAt,
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
          other.swipeDurations == this.swipeDurations &&
          other.metadata == this.metadata &&
          other.swipeMetadata == this.swipeMetadata &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<int> position;
  final Value<String> sender;
  final Value<bool> isUser;
  final Value<String?> characterId;
  final Value<String> swipes;
  final Value<int> swipeIndex;
  final Value<String> swipeDurations;
  final Value<String?> metadata;
  final Value<String?> swipeMetadata;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
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
    this.metadata = const Value.absent(),
    this.swipeMetadata = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String sessionId,
    required int position,
    required String sender,
    required bool isUser,
    this.characterId = const Value.absent(),
    this.swipes = const Value.absent(),
    this.swipeIndex = const Value.absent(),
    this.swipeDurations = const Value.absent(),
    this.metadata = const Value.absent(),
    this.swipeMetadata = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       position = Value(position),
       sender = Value(sender),
       isUser = Value(isUser);
  static Insertable<Message> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? position,
    Expression<String>? sender,
    Expression<bool>? isUser,
    Expression<String>? characterId,
    Expression<String>? swipes,
    Expression<int>? swipeIndex,
    Expression<String>? swipeDurations,
    Expression<String>? metadata,
    Expression<String>? swipeMetadata,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
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
      if (metadata != null) 'metadata': metadata,
      if (swipeMetadata != null) 'swipe_metadata': swipeMetadata,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<int>? position,
    Value<String>? sender,
    Value<bool>? isUser,
    Value<String?>? characterId,
    Value<String>? swipes,
    Value<int>? swipeIndex,
    Value<String>? swipeDurations,
    Value<String?>? metadata,
    Value<String?>? swipeMetadata,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
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
      metadata: metadata ?? this.metadata,
      swipeMetadata: swipeMetadata ?? this.swipeMetadata,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
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
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (swipeMetadata.present) {
      map['swipe_metadata'] = Variable<String>(swipeMetadata.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
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
          ..write('swipeDurations: $swipeDurations, ')
          ..write('metadata: $metadata, ')
          ..write('swipeMetadata: $swipeMetadata, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
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
    updatedAt,
    deletedAt,
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
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
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
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
  final DateTime updatedAt;
  final DateTime? deletedAt;
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
    required this.updatedAt,
    this.deletedAt,
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
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
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
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
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
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
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
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
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
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
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
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
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
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
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
          ..write('systemPrompt: $systemPrompt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
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
    updatedAt,
    deletedAt,
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
          other.systemPrompt == this.systemPrompt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
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
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
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
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
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
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
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
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
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
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
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
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
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
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
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
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FoldersTable extends Folders with TableInfo<$FoldersTable, Folder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    parentId,
    updatedAt,
    deletedAt,
  ];
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
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
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
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class Folder extends DataClass implements Insertable<Folder> {
  final String id;
  final String name;
  final String? parentId;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Folder({
    required this.id,
    required this.name,
    this.parentId,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
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
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Folder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Folder(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'parentId': serializer.toJson<String?>(parentId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Folder copyWith({
    String? id,
    String? name,
    Value<String?> parentId = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Folder(
    id: id ?? this.id,
    name: name ?? this.name,
    parentId: parentId.present ? parentId.value : this.parentId,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Folder copyWithCompanion(FoldersCompanion data) {
    return Folder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Folder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, parentId, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Folder &&
          other.id == this.id &&
          other.name == this.name &&
          other.parentId == this.parentId &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class FoldersCompanion extends UpdateCompanion<Folder> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> parentId;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.parentId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoldersCompanion.insert({
    required String id,
    required String name,
    this.parentId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Folder> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? parentId,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (parentId != null) 'parent_id': parentId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? parentId,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('parentId: $parentId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
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
  static const VerificationMeta _learnedFactsMeta = const VerificationMeta(
    'learnedFacts',
  );
  @override
  late final GeneratedColumn<String> learnedFacts = GeneratedColumn<String>(
    'learned_facts',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    name,
    description,
    persona,
    learnedFacts,
    avatarPath,
    isActive,
    updatedAt,
    deletedAt,
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
    if (data.containsKey('learned_facts')) {
      context.handle(
        _learnedFactsMeta,
        learnedFacts.isAcceptableOrUnknown(
          data['learned_facts']!,
          _learnedFactsMeta,
        ),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
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
      learnedFacts: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}learned_facts'],
      )!,
      avatarPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_path'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
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
  final String learnedFacts;
  final String? avatarPath;
  final bool isActive;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Persona({
    required this.id,
    required this.title,
    required this.name,
    required this.description,
    required this.persona,
    required this.learnedFacts,
    this.avatarPath,
    required this.isActive,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['persona'] = Variable<String>(persona);
    map['learned_facts'] = Variable<String>(learnedFacts);
    if (!nullToAbsent || avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PersonasCompanion toCompanion(bool nullToAbsent) {
    return PersonasCompanion(
      id: Value(id),
      title: Value(title),
      name: Value(name),
      description: Value(description),
      persona: Value(persona),
      learnedFacts: Value(learnedFacts),
      avatarPath: avatarPath == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarPath),
      isActive: Value(isActive),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
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
      learnedFacts: serializer.fromJson<String>(json['learnedFacts']),
      avatarPath: serializer.fromJson<String?>(json['avatarPath']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
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
      'learnedFacts': serializer.toJson<String>(learnedFacts),
      'avatarPath': serializer.toJson<String?>(avatarPath),
      'isActive': serializer.toJson<bool>(isActive),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Persona copyWith({
    String? id,
    String? title,
    String? name,
    String? description,
    String? persona,
    String? learnedFacts,
    Value<String?> avatarPath = const Value.absent(),
    bool? isActive,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Persona(
    id: id ?? this.id,
    title: title ?? this.title,
    name: name ?? this.name,
    description: description ?? this.description,
    persona: persona ?? this.persona,
    learnedFacts: learnedFacts ?? this.learnedFacts,
    avatarPath: avatarPath.present ? avatarPath.value : this.avatarPath,
    isActive: isActive ?? this.isActive,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
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
      learnedFacts: data.learnedFacts.present
          ? data.learnedFacts.value
          : this.learnedFacts,
      avatarPath: data.avatarPath.present
          ? data.avatarPath.value
          : this.avatarPath,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
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
          ..write('learnedFacts: $learnedFacts, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    name,
    description,
    persona,
    learnedFacts,
    avatarPath,
    isActive,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Persona &&
          other.id == this.id &&
          other.title == this.title &&
          other.name == this.name &&
          other.description == this.description &&
          other.persona == this.persona &&
          other.learnedFacts == this.learnedFacts &&
          other.avatarPath == this.avatarPath &&
          other.isActive == this.isActive &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class PersonasCompanion extends UpdateCompanion<Persona> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> name;
  final Value<String> description;
  final Value<String> persona;
  final Value<String> learnedFacts;
  final Value<String?> avatarPath;
  final Value<bool> isActive;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const PersonasCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.persona = const Value.absent(),
    this.learnedFacts = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonasCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.persona = const Value.absent(),
    this.learnedFacts = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.isActive = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<Persona> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? persona,
    Expression<String>? learnedFacts,
    Expression<String>? avatarPath,
    Expression<bool>? isActive,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (persona != null) 'persona': persona,
      if (learnedFacts != null) 'learned_facts': learnedFacts,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (isActive != null) 'is_active': isActive,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonasCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? name,
    Value<String>? description,
    Value<String>? persona,
    Value<String>? learnedFacts,
    Value<String?>? avatarPath,
    Value<bool>? isActive,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return PersonasCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      name: name ?? this.name,
      description: description ?? this.description,
      persona: persona ?? this.persona,
      learnedFacts: learnedFacts ?? this.learnedFacts,
      avatarPath: avatarPath ?? this.avatarPath,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (learnedFacts.present) {
      map['learned_facts'] = Variable<String>(learnedFacts.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
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
          ..write('learnedFacts: $learnedFacts, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('isActive: $isActive, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    lorebook,
    linkedCharacterName,
    updatedAt,
    deletedAt,
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
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
        DriftSqlType.string,
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
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $WorldsTable createAlias(String alias) {
    return $WorldsTable(attachedDatabase, alias);
  }
}

class World extends DataClass implements Insertable<World> {
  final String id;
  final String name;
  final String description;
  final String? lorebook;
  final String? linkedCharacterName;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const World({
    required this.id,
    required this.name,
    required this.description,
    this.lorebook,
    this.linkedCharacterName,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || lorebook != null) {
      map['lorebook'] = Variable<String>(lorebook);
    }
    if (!nullToAbsent || linkedCharacterName != null) {
      map['linked_character_name'] = Variable<String>(linkedCharacterName);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
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
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory World.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return World(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      lorebook: serializer.fromJson<String?>(json['lorebook']),
      linkedCharacterName: serializer.fromJson<String?>(
        json['linkedCharacterName'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'lorebook': serializer.toJson<String?>(lorebook),
      'linkedCharacterName': serializer.toJson<String?>(linkedCharacterName),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  World copyWith({
    String? id,
    String? name,
    String? description,
    Value<String?> lorebook = const Value.absent(),
    Value<String?> linkedCharacterName = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => World(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    lorebook: lorebook.present ? lorebook.value : this.lorebook,
    linkedCharacterName: linkedCharacterName.present
        ? linkedCharacterName.value
        : this.linkedCharacterName,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
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
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('World(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('lorebook: $lorebook, ')
          ..write('linkedCharacterName: $linkedCharacterName, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    lorebook,
    linkedCharacterName,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is World &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.lorebook == this.lorebook &&
          other.linkedCharacterName == this.linkedCharacterName &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class WorldsCompanion extends UpdateCompanion<World> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> description;
  final Value<String?> lorebook;
  final Value<String?> linkedCharacterName;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const WorldsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.lorebook = const Value.absent(),
    this.linkedCharacterName = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorldsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.lorebook = const Value.absent(),
    this.linkedCharacterName = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<World> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? lorebook,
    Expression<String>? linkedCharacterName,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (lorebook != null) 'lorebook': lorebook,
      if (linkedCharacterName != null)
        'linked_character_name': linkedCharacterName,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorldsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? description,
    Value<String?>? lorebook,
    Value<String?>? linkedCharacterName,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return WorldsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      lorebook: lorebook ?? this.lorebook,
      linkedCharacterName: linkedCharacterName ?? this.linkedCharacterName,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
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
          ..write('linkedCharacterName: $linkedCharacterName, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageEmbeddingsTable extends MessageEmbeddings
    with TableInfo<$MessageEmbeddingsTable, MessageEmbedding> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageEmbeddingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _positionStartMeta = const VerificationMeta(
    'positionStart',
  );
  @override
  late final GeneratedColumn<int> positionStart = GeneratedColumn<int>(
    'position_start',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionEndMeta = const VerificationMeta(
    'positionEnd',
  );
  @override
  late final GeneratedColumn<int> positionEnd = GeneratedColumn<int>(
    'position_end',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _embeddingMeta = const VerificationMeta(
    'embedding',
  );
  @override
  late final GeneratedColumn<Uint8List> embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dimensionsMeta = const VerificationMeta(
    'dimensions',
  );
  @override
  late final GeneratedColumn<int> dimensions = GeneratedColumn<int>(
    'dimensions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    characterId,
    positionStart,
    positionEnd,
    content,
    embedding,
    dimensions,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_embeddings';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageEmbedding> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
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
    if (data.containsKey('position_start')) {
      context.handle(
        _positionStartMeta,
        positionStart.isAcceptableOrUnknown(
          data['position_start']!,
          _positionStartMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_positionStartMeta);
    }
    if (data.containsKey('position_end')) {
      context.handle(
        _positionEndMeta,
        positionEnd.isAcceptableOrUnknown(
          data['position_end']!,
          _positionEndMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_positionEndMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('embedding')) {
      context.handle(
        _embeddingMeta,
        embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta),
      );
    } else if (isInserting) {
      context.missing(_embeddingMeta);
    }
    if (data.containsKey('dimensions')) {
      context.handle(
        _dimensionsMeta,
        dimensions.isAcceptableOrUnknown(data['dimensions']!, _dimensionsMeta),
      );
    } else if (isInserting) {
      context.missing(_dimensionsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageEmbedding map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageEmbedding(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_id'],
      ),
      positionStart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_start'],
      )!,
      positionEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_end'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      embedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}embedding'],
      )!,
      dimensions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dimensions'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MessageEmbeddingsTable createAlias(String alias) {
    return $MessageEmbeddingsTable(attachedDatabase, alias);
  }
}

class MessageEmbedding extends DataClass
    implements Insertable<MessageEmbedding> {
  final String id;
  final String sessionId;
  final String? characterId;
  final int positionStart;
  final int positionEnd;
  final String content;
  final Uint8List embedding;
  final int dimensions;
  final DateTime createdAt;
  const MessageEmbedding({
    required this.id,
    required this.sessionId,
    this.characterId,
    required this.positionStart,
    required this.positionEnd,
    required this.content,
    required this.embedding,
    required this.dimensions,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    if (!nullToAbsent || characterId != null) {
      map['character_id'] = Variable<String>(characterId);
    }
    map['position_start'] = Variable<int>(positionStart);
    map['position_end'] = Variable<int>(positionEnd);
    map['content'] = Variable<String>(content);
    map['embedding'] = Variable<Uint8List>(embedding);
    map['dimensions'] = Variable<int>(dimensions);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MessageEmbeddingsCompanion toCompanion(bool nullToAbsent) {
    return MessageEmbeddingsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      characterId: characterId == null && nullToAbsent
          ? const Value.absent()
          : Value(characterId),
      positionStart: Value(positionStart),
      positionEnd: Value(positionEnd),
      content: Value(content),
      embedding: Value(embedding),
      dimensions: Value(dimensions),
      createdAt: Value(createdAt),
    );
  }

  factory MessageEmbedding.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageEmbedding(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      characterId: serializer.fromJson<String?>(json['characterId']),
      positionStart: serializer.fromJson<int>(json['positionStart']),
      positionEnd: serializer.fromJson<int>(json['positionEnd']),
      content: serializer.fromJson<String>(json['content']),
      embedding: serializer.fromJson<Uint8List>(json['embedding']),
      dimensions: serializer.fromJson<int>(json['dimensions']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'characterId': serializer.toJson<String?>(characterId),
      'positionStart': serializer.toJson<int>(positionStart),
      'positionEnd': serializer.toJson<int>(positionEnd),
      'content': serializer.toJson<String>(content),
      'embedding': serializer.toJson<Uint8List>(embedding),
      'dimensions': serializer.toJson<int>(dimensions),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MessageEmbedding copyWith({
    String? id,
    String? sessionId,
    Value<String?> characterId = const Value.absent(),
    int? positionStart,
    int? positionEnd,
    String? content,
    Uint8List? embedding,
    int? dimensions,
    DateTime? createdAt,
  }) => MessageEmbedding(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    characterId: characterId.present ? characterId.value : this.characterId,
    positionStart: positionStart ?? this.positionStart,
    positionEnd: positionEnd ?? this.positionEnd,
    content: content ?? this.content,
    embedding: embedding ?? this.embedding,
    dimensions: dimensions ?? this.dimensions,
    createdAt: createdAt ?? this.createdAt,
  );
  MessageEmbedding copyWithCompanion(MessageEmbeddingsCompanion data) {
    return MessageEmbedding(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      positionStart: data.positionStart.present
          ? data.positionStart.value
          : this.positionStart,
      positionEnd: data.positionEnd.present
          ? data.positionEnd.value
          : this.positionEnd,
      content: data.content.present ? data.content.value : this.content,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      dimensions: data.dimensions.present
          ? data.dimensions.value
          : this.dimensions,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageEmbedding(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('characterId: $characterId, ')
          ..write('positionStart: $positionStart, ')
          ..write('positionEnd: $positionEnd, ')
          ..write('content: $content, ')
          ..write('embedding: $embedding, ')
          ..write('dimensions: $dimensions, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    characterId,
    positionStart,
    positionEnd,
    content,
    $driftBlobEquality.hash(embedding),
    dimensions,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageEmbedding &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.characterId == this.characterId &&
          other.positionStart == this.positionStart &&
          other.positionEnd == this.positionEnd &&
          other.content == this.content &&
          $driftBlobEquality.equals(other.embedding, this.embedding) &&
          other.dimensions == this.dimensions &&
          other.createdAt == this.createdAt);
}

class MessageEmbeddingsCompanion extends UpdateCompanion<MessageEmbedding> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String?> characterId;
  final Value<int> positionStart;
  final Value<int> positionEnd;
  final Value<String> content;
  final Value<Uint8List> embedding;
  final Value<int> dimensions;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MessageEmbeddingsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.characterId = const Value.absent(),
    this.positionStart = const Value.absent(),
    this.positionEnd = const Value.absent(),
    this.content = const Value.absent(),
    this.embedding = const Value.absent(),
    this.dimensions = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageEmbeddingsCompanion.insert({
    required String id,
    required String sessionId,
    this.characterId = const Value.absent(),
    required int positionStart,
    required int positionEnd,
    required String content,
    required Uint8List embedding,
    required int dimensions,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       positionStart = Value(positionStart),
       positionEnd = Value(positionEnd),
       content = Value(content),
       embedding = Value(embedding),
       dimensions = Value(dimensions);
  static Insertable<MessageEmbedding> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? characterId,
    Expression<int>? positionStart,
    Expression<int>? positionEnd,
    Expression<String>? content,
    Expression<Uint8List>? embedding,
    Expression<int>? dimensions,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (characterId != null) 'character_id': characterId,
      if (positionStart != null) 'position_start': positionStart,
      if (positionEnd != null) 'position_end': positionEnd,
      if (content != null) 'content': content,
      if (embedding != null) 'embedding': embedding,
      if (dimensions != null) 'dimensions': dimensions,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageEmbeddingsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String?>? characterId,
    Value<int>? positionStart,
    Value<int>? positionEnd,
    Value<String>? content,
    Value<Uint8List>? embedding,
    Value<int>? dimensions,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return MessageEmbeddingsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      characterId: characterId ?? this.characterId,
      positionStart: positionStart ?? this.positionStart,
      positionEnd: positionEnd ?? this.positionEnd,
      content: content ?? this.content,
      embedding: embedding ?? this.embedding,
      dimensions: dimensions ?? this.dimensions,
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
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<String>(characterId.value);
    }
    if (positionStart.present) {
      map['position_start'] = Variable<int>(positionStart.value);
    }
    if (positionEnd.present) {
      map['position_end'] = Variable<int>(positionEnd.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(embedding.value);
    }
    if (dimensions.present) {
      map['dimensions'] = Variable<int>(dimensions.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageEmbeddingsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('characterId: $characterId, ')
          ..write('positionStart: $positionStart, ')
          ..write('positionEnd: $positionEnd, ')
          ..write('content: $content, ')
          ..write('embedding: $embedding, ')
          ..write('dimensions: $dimensions, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DataBankEntriesTable extends DataBankEntries
    with TableInfo<$DataBankEntriesTable, DataBankEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DataBankEntriesTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumn<String> characterId = GeneratedColumn<String>(
    'character_id',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _embeddingMeta = const VerificationMeta(
    'embedding',
  );
  @override
  late final GeneratedColumn<Uint8List> embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dimensionsMeta = const VerificationMeta(
    'dimensions',
  );
  @override
  late final GeneratedColumn<int> dimensions = GeneratedColumn<int>(
    'dimensions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    characterId,
    title,
    content,
    embedding,
    dimensions,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'data_bank_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DataBankEntry> instance, {
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
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('embedding')) {
      context.handle(
        _embeddingMeta,
        embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta),
      );
    }
    if (data.containsKey('dimensions')) {
      context.handle(
        _dimensionsMeta,
        dimensions.isAcceptableOrUnknown(data['dimensions']!, _dimensionsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DataBankEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DataBankEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      embedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}embedding'],
      ),
      dimensions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dimensions'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DataBankEntriesTable createAlias(String alias) {
    return $DataBankEntriesTable(attachedDatabase, alias);
  }
}

class DataBankEntry extends DataClass implements Insertable<DataBankEntry> {
  final String id;
  final String characterId;
  final String title;
  final String content;
  final Uint8List? embedding;
  final int dimensions;
  final DateTime createdAt;
  const DataBankEntry({
    required this.id,
    required this.characterId,
    required this.title,
    required this.content,
    this.embedding,
    required this.dimensions,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['character_id'] = Variable<String>(characterId);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || embedding != null) {
      map['embedding'] = Variable<Uint8List>(embedding);
    }
    map['dimensions'] = Variable<int>(dimensions);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DataBankEntriesCompanion toCompanion(bool nullToAbsent) {
    return DataBankEntriesCompanion(
      id: Value(id),
      characterId: Value(characterId),
      title: Value(title),
      content: Value(content),
      embedding: embedding == null && nullToAbsent
          ? const Value.absent()
          : Value(embedding),
      dimensions: Value(dimensions),
      createdAt: Value(createdAt),
    );
  }

  factory DataBankEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DataBankEntry(
      id: serializer.fromJson<String>(json['id']),
      characterId: serializer.fromJson<String>(json['characterId']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      embedding: serializer.fromJson<Uint8List?>(json['embedding']),
      dimensions: serializer.fromJson<int>(json['dimensions']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'characterId': serializer.toJson<String>(characterId),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'embedding': serializer.toJson<Uint8List?>(embedding),
      'dimensions': serializer.toJson<int>(dimensions),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DataBankEntry copyWith({
    String? id,
    String? characterId,
    String? title,
    String? content,
    Value<Uint8List?> embedding = const Value.absent(),
    int? dimensions,
    DateTime? createdAt,
  }) => DataBankEntry(
    id: id ?? this.id,
    characterId: characterId ?? this.characterId,
    title: title ?? this.title,
    content: content ?? this.content,
    embedding: embedding.present ? embedding.value : this.embedding,
    dimensions: dimensions ?? this.dimensions,
    createdAt: createdAt ?? this.createdAt,
  );
  DataBankEntry copyWithCompanion(DataBankEntriesCompanion data) {
    return DataBankEntry(
      id: data.id.present ? data.id.value : this.id,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      dimensions: data.dimensions.present
          ? data.dimensions.value
          : this.dimensions,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DataBankEntry(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('embedding: $embedding, ')
          ..write('dimensions: $dimensions, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    characterId,
    title,
    content,
    $driftBlobEquality.hash(embedding),
    dimensions,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DataBankEntry &&
          other.id == this.id &&
          other.characterId == this.characterId &&
          other.title == this.title &&
          other.content == this.content &&
          $driftBlobEquality.equals(other.embedding, this.embedding) &&
          other.dimensions == this.dimensions &&
          other.createdAt == this.createdAt);
}

class DataBankEntriesCompanion extends UpdateCompanion<DataBankEntry> {
  final Value<String> id;
  final Value<String> characterId;
  final Value<String> title;
  final Value<String> content;
  final Value<Uint8List?> embedding;
  final Value<int> dimensions;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DataBankEntriesCompanion({
    this.id = const Value.absent(),
    this.characterId = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.embedding = const Value.absent(),
    this.dimensions = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DataBankEntriesCompanion.insert({
    required String id,
    required String characterId,
    required String title,
    required String content,
    this.embedding = const Value.absent(),
    this.dimensions = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       characterId = Value(characterId),
       title = Value(title),
       content = Value(content);
  static Insertable<DataBankEntry> custom({
    Expression<String>? id,
    Expression<String>? characterId,
    Expression<String>? title,
    Expression<String>? content,
    Expression<Uint8List>? embedding,
    Expression<int>? dimensions,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (characterId != null) 'character_id': characterId,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (embedding != null) 'embedding': embedding,
      if (dimensions != null) 'dimensions': dimensions,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DataBankEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? characterId,
    Value<String>? title,
    Value<String>? content,
    Value<Uint8List?>? embedding,
    Value<int>? dimensions,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return DataBankEntriesCompanion(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      title: title ?? this.title,
      content: content ?? this.content,
      embedding: embedding ?? this.embedding,
      dimensions: dimensions ?? this.dimensions,
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
    if (characterId.present) {
      map['character_id'] = Variable<String>(characterId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(embedding.value);
    }
    if (dimensions.present) {
      map['dimensions'] = Variable<int>(dimensions.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DataBankEntriesCompanion(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('embedding: $embedding, ')
          ..write('dimensions: $dimensions, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ObjectivesTable extends Objectives
    with TableInfo<$ObjectivesTable, Objective> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ObjectivesTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumn<String> characterId = GeneratedColumn<String>(
    'character_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _objectiveMeta = const VerificationMeta(
    'objective',
  );
  @override
  late final GeneratedColumn<String> objective = GeneratedColumn<String>(
    'objective',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tasksMeta = const VerificationMeta('tasks');
  @override
  late final GeneratedColumn<String> tasks = GeneratedColumn<String>(
    'tasks',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _checkFrequencyMeta = const VerificationMeta(
    'checkFrequency',
  );
  @override
  late final GeneratedColumn<int> checkFrequency = GeneratedColumn<int>(
    'check_frequency',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _injectionDepthMeta = const VerificationMeta(
    'injectionDepth',
  );
  @override
  late final GeneratedColumn<int> injectionDepth = GeneratedColumn<int>(
    'injection_depth',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    characterId,
    objective,
    tasks,
    active,
    checkFrequency,
    injectionDepth,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'objectives';
  @override
  VerificationContext validateIntegrity(
    Insertable<Objective> instance, {
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
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('objective')) {
      context.handle(
        _objectiveMeta,
        objective.isAcceptableOrUnknown(data['objective']!, _objectiveMeta),
      );
    } else if (isInserting) {
      context.missing(_objectiveMeta);
    }
    if (data.containsKey('tasks')) {
      context.handle(
        _tasksMeta,
        tasks.isAcceptableOrUnknown(data['tasks']!, _tasksMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('check_frequency')) {
      context.handle(
        _checkFrequencyMeta,
        checkFrequency.isAcceptableOrUnknown(
          data['check_frequency']!,
          _checkFrequencyMeta,
        ),
      );
    }
    if (data.containsKey('injection_depth')) {
      context.handle(
        _injectionDepthMeta,
        injectionDepth.isAcceptableOrUnknown(
          data['injection_depth']!,
          _injectionDepthMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Objective map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Objective(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_id'],
      )!,
      objective: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}objective'],
      )!,
      tasks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tasks'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      checkFrequency: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}check_frequency'],
      )!,
      injectionDepth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}injection_depth'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ObjectivesTable createAlias(String alias) {
    return $ObjectivesTable(attachedDatabase, alias);
  }
}

class Objective extends DataClass implements Insertable<Objective> {
  final String id;
  final String characterId;
  final String objective;
  final String tasks;
  final bool active;
  final int checkFrequency;
  final int injectionDepth;
  final DateTime createdAt;
  const Objective({
    required this.id,
    required this.characterId,
    required this.objective,
    required this.tasks,
    required this.active,
    required this.checkFrequency,
    required this.injectionDepth,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['character_id'] = Variable<String>(characterId);
    map['objective'] = Variable<String>(objective);
    map['tasks'] = Variable<String>(tasks);
    map['active'] = Variable<bool>(active);
    map['check_frequency'] = Variable<int>(checkFrequency);
    map['injection_depth'] = Variable<int>(injectionDepth);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ObjectivesCompanion toCompanion(bool nullToAbsent) {
    return ObjectivesCompanion(
      id: Value(id),
      characterId: Value(characterId),
      objective: Value(objective),
      tasks: Value(tasks),
      active: Value(active),
      checkFrequency: Value(checkFrequency),
      injectionDepth: Value(injectionDepth),
      createdAt: Value(createdAt),
    );
  }

  factory Objective.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Objective(
      id: serializer.fromJson<String>(json['id']),
      characterId: serializer.fromJson<String>(json['characterId']),
      objective: serializer.fromJson<String>(json['objective']),
      tasks: serializer.fromJson<String>(json['tasks']),
      active: serializer.fromJson<bool>(json['active']),
      checkFrequency: serializer.fromJson<int>(json['checkFrequency']),
      injectionDepth: serializer.fromJson<int>(json['injectionDepth']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'characterId': serializer.toJson<String>(characterId),
      'objective': serializer.toJson<String>(objective),
      'tasks': serializer.toJson<String>(tasks),
      'active': serializer.toJson<bool>(active),
      'checkFrequency': serializer.toJson<int>(checkFrequency),
      'injectionDepth': serializer.toJson<int>(injectionDepth),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Objective copyWith({
    String? id,
    String? characterId,
    String? objective,
    String? tasks,
    bool? active,
    int? checkFrequency,
    int? injectionDepth,
    DateTime? createdAt,
  }) => Objective(
    id: id ?? this.id,
    characterId: characterId ?? this.characterId,
    objective: objective ?? this.objective,
    tasks: tasks ?? this.tasks,
    active: active ?? this.active,
    checkFrequency: checkFrequency ?? this.checkFrequency,
    injectionDepth: injectionDepth ?? this.injectionDepth,
    createdAt: createdAt ?? this.createdAt,
  );
  Objective copyWithCompanion(ObjectivesCompanion data) {
    return Objective(
      id: data.id.present ? data.id.value : this.id,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      objective: data.objective.present ? data.objective.value : this.objective,
      tasks: data.tasks.present ? data.tasks.value : this.tasks,
      active: data.active.present ? data.active.value : this.active,
      checkFrequency: data.checkFrequency.present
          ? data.checkFrequency.value
          : this.checkFrequency,
      injectionDepth: data.injectionDepth.present
          ? data.injectionDepth.value
          : this.injectionDepth,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Objective(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('objective: $objective, ')
          ..write('tasks: $tasks, ')
          ..write('active: $active, ')
          ..write('checkFrequency: $checkFrequency, ')
          ..write('injectionDepth: $injectionDepth, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    characterId,
    objective,
    tasks,
    active,
    checkFrequency,
    injectionDepth,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Objective &&
          other.id == this.id &&
          other.characterId == this.characterId &&
          other.objective == this.objective &&
          other.tasks == this.tasks &&
          other.active == this.active &&
          other.checkFrequency == this.checkFrequency &&
          other.injectionDepth == this.injectionDepth &&
          other.createdAt == this.createdAt);
}

class ObjectivesCompanion extends UpdateCompanion<Objective> {
  final Value<String> id;
  final Value<String> characterId;
  final Value<String> objective;
  final Value<String> tasks;
  final Value<bool> active;
  final Value<int> checkFrequency;
  final Value<int> injectionDepth;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ObjectivesCompanion({
    this.id = const Value.absent(),
    this.characterId = const Value.absent(),
    this.objective = const Value.absent(),
    this.tasks = const Value.absent(),
    this.active = const Value.absent(),
    this.checkFrequency = const Value.absent(),
    this.injectionDepth = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ObjectivesCompanion.insert({
    required String id,
    required String characterId,
    required String objective,
    this.tasks = const Value.absent(),
    this.active = const Value.absent(),
    this.checkFrequency = const Value.absent(),
    this.injectionDepth = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       characterId = Value(characterId),
       objective = Value(objective);
  static Insertable<Objective> custom({
    Expression<String>? id,
    Expression<String>? characterId,
    Expression<String>? objective,
    Expression<String>? tasks,
    Expression<bool>? active,
    Expression<int>? checkFrequency,
    Expression<int>? injectionDepth,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (characterId != null) 'character_id': characterId,
      if (objective != null) 'objective': objective,
      if (tasks != null) 'tasks': tasks,
      if (active != null) 'active': active,
      if (checkFrequency != null) 'check_frequency': checkFrequency,
      if (injectionDepth != null) 'injection_depth': injectionDepth,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ObjectivesCompanion copyWith({
    Value<String>? id,
    Value<String>? characterId,
    Value<String>? objective,
    Value<String>? tasks,
    Value<bool>? active,
    Value<int>? checkFrequency,
    Value<int>? injectionDepth,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ObjectivesCompanion(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      objective: objective ?? this.objective,
      tasks: tasks ?? this.tasks,
      active: active ?? this.active,
      checkFrequency: checkFrequency ?? this.checkFrequency,
      injectionDepth: injectionDepth ?? this.injectionDepth,
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
    if (characterId.present) {
      map['character_id'] = Variable<String>(characterId.value);
    }
    if (objective.present) {
      map['objective'] = Variable<String>(objective.value);
    }
    if (tasks.present) {
      map['tasks'] = Variable<String>(tasks.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (checkFrequency.present) {
      map['check_frequency'] = Variable<int>(checkFrequency.value);
    }
    if (injectionDepth.present) {
      map['injection_depth'] = Variable<int>(injectionDepth.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ObjectivesCompanion(')
          ..write('id: $id, ')
          ..write('characterId: $characterId, ')
          ..write('objective: $objective, ')
          ..write('tasks: $tasks, ')
          ..write('active: $active, ')
          ..write('checkFrequency: $checkFrequency, ')
          ..write('injectionDepth: $injectionDepth, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoryProjectsTable extends StoryProjects
    with TableInfo<$StoryProjectsTable, StoryProject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoryProjectsTable(this.attachedDatabase, [this._alias]);
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
    defaultValue: const Constant('Untitled Story'),
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    data,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'story_projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoryProject> instance, {
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
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoryProject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoryProject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $StoryProjectsTable createAlias(String alias) {
    return $StoryProjectsTable(attachedDatabase, alias);
  }
}

class StoryProject extends DataClass implements Insertable<StoryProject> {
  final String id;
  final String title;
  final String data;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const StoryProject({
    required this.id,
    required this.title,
    required this.data,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['data'] = Variable<String>(data);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  StoryProjectsCompanion toCompanion(bool nullToAbsent) {
    return StoryProjectsCompanion(
      id: Value(id),
      title: Value(title),
      data: Value(data),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory StoryProject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoryProject(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      data: serializer.fromJson<String>(json['data']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'data': serializer.toJson<String>(data),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  StoryProject copyWith({
    String? id,
    String? title,
    String? data,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => StoryProject(
    id: id ?? this.id,
    title: title ?? this.title,
    data: data ?? this.data,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  StoryProject copyWithCompanion(StoryProjectsCompanion data) {
    return StoryProject(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      data: data.data.present ? data.data.value : this.data,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoryProject(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('data: $data, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, data, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoryProject &&
          other.id == this.id &&
          other.title == this.title &&
          other.data == this.data &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class StoryProjectsCompanion extends UpdateCompanion<StoryProject> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> data;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const StoryProjectsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.data = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoryProjectsCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    required String data,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       data = Value(data);
  static Insertable<StoryProject> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? data,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (data != null) 'data': data,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoryProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? data,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return StoryProjectsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
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
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoryProjectsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('data: $data, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastModifiedAtMeta = const VerificationMeta(
    'lastModifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastModifiedAt =
      GeneratedColumn<DateTime>(
        'last_modified_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  @override
  List<GeneratedColumn> get $columns => [id, version, lastModifiedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('last_modified_at')) {
      context.handle(
        _lastModifiedAtMeta,
        lastModifiedAt.isAcceptableOrUnknown(
          data['last_modified_at']!,
          _lastModifiedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      lastModifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_modified_at'],
      )!,
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetaData extends DataClass implements Insertable<SyncMetaData> {
  final int id;
  final int version;
  final DateTime lastModifiedAt;
  const SyncMetaData({
    required this.id,
    required this.version,
    required this.lastModifiedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['version'] = Variable<int>(version);
    map['last_modified_at'] = Variable<DateTime>(lastModifiedAt);
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(
      id: Value(id),
      version: Value(version),
      lastModifiedAt: Value(lastModifiedAt),
    );
  }

  factory SyncMetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaData(
      id: serializer.fromJson<int>(json['id']),
      version: serializer.fromJson<int>(json['version']),
      lastModifiedAt: serializer.fromJson<DateTime>(json['lastModifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'version': serializer.toJson<int>(version),
      'lastModifiedAt': serializer.toJson<DateTime>(lastModifiedAt),
    };
  }

  SyncMetaData copyWith({int? id, int? version, DateTime? lastModifiedAt}) =>
      SyncMetaData(
        id: id ?? this.id,
        version: version ?? this.version,
        lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      );
  SyncMetaData copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaData(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      lastModifiedAt: data.lastModifiedAt.present
          ? data.lastModifiedAt.value
          : this.lastModifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaData(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('lastModifiedAt: $lastModifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, version, lastModifiedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaData &&
          other.id == this.id &&
          other.version == this.version &&
          other.lastModifiedAt == this.lastModifiedAt);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaData> {
  final Value<int> id;
  final Value<int> version;
  final Value<DateTime> lastModifiedAt;
  const SyncMetaCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.lastModifiedAt = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.lastModifiedAt = const Value.absent(),
  });
  static Insertable<SyncMetaData> custom({
    Expression<int>? id,
    Expression<int>? version,
    Expression<DateTime>? lastModifiedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (lastModifiedAt != null) 'last_modified_at': lastModifiedAt,
    });
  }

  SyncMetaCompanion copyWith({
    Value<int>? id,
    Value<int>? version,
    Value<DateTime>? lastModifiedAt,
  }) {
    return SyncMetaCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (lastModifiedAt.present) {
      map['last_modified_at'] = Variable<DateTime>(lastModifiedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('lastModifiedAt: $lastModifiedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CharactersTable characters = $CharactersTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $GroupsTable groups = $GroupsTable(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $PersonasTable personas = $PersonasTable(this);
  late final $WorldsTable worlds = $WorldsTable(this);
  late final $MessageEmbeddingsTable messageEmbeddings =
      $MessageEmbeddingsTable(this);
  late final $DataBankEntriesTable dataBankEntries = $DataBankEntriesTable(
    this,
  );
  late final $ObjectivesTable objectives = $ObjectivesTable(this);
  late final $StoryProjectsTable storyProjects = $StoryProjectsTable(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    characters,
    sessions,
    messages,
    groups,
    folders,
    personas,
    worlds,
    messageEmbeddings,
    dataBankEntries,
    objectives,
    storyProjects,
    syncMeta,
  ];
}

typedef $$CharactersTableCreateCompanionBuilder =
    CharactersCompanion Function({
      required String id,
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
      Value<String?> folderId,
      Value<String?> lorebook,
      Value<String> worldNames,
      Value<String> memorySources,
      Value<String> evolvedPersonality,
      Value<String> evolvedScenario,
      Value<int> evolutionCount,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$CharactersTableUpdateCompanionBuilder =
    CharactersCompanion Function({
      Value<String> id,
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
      Value<String?> folderId,
      Value<String?> lorebook,
      Value<String> worldNames,
      Value<String> memorySources,
      Value<String> evolvedPersonality,
      Value<String> evolvedScenario,
      Value<int> evolutionCount,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$CharactersTableFilterComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableFilterComposer({
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

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
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

  ColumnFilters<String> get memorySources => $composableBuilder(
    column: $table.memorySources,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evolvedPersonality => $composableBuilder(
    column: $table.evolvedPersonality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evolvedScenario => $composableBuilder(
    column: $table.evolvedScenario,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get evolutionCount => $composableBuilder(
    column: $table.evolutionCount,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
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

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
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

  ColumnOrderings<String> get memorySources => $composableBuilder(
    column: $table.memorySources,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evolvedPersonality => $composableBuilder(
    column: $table.evolvedPersonality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evolvedScenario => $composableBuilder(
    column: $table.evolvedScenario,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get evolutionCount => $composableBuilder(
    column: $table.evolutionCount,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
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
  GeneratedColumn<String> get id =>
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

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<String> get lorebook =>
      $composableBuilder(column: $table.lorebook, builder: (column) => column);

  GeneratedColumn<String> get worldNames => $composableBuilder(
    column: $table.worldNames,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memorySources => $composableBuilder(
    column: $table.memorySources,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evolvedPersonality => $composableBuilder(
    column: $table.evolvedPersonality,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evolvedScenario => $composableBuilder(
    column: $table.evolvedScenario,
    builder: (column) => column,
  );

  GeneratedColumn<int> get evolutionCount => $composableBuilder(
    column: $table.evolutionCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
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
          (
            Character,
            BaseReferences<_$AppDatabase, $CharactersTable, Character>,
          ),
          Character,
          PrefetchHooks Function()
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
                Value<String> id = const Value.absent(),
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
                Value<String?> folderId = const Value.absent(),
                Value<String?> lorebook = const Value.absent(),
                Value<String> worldNames = const Value.absent(),
                Value<String> memorySources = const Value.absent(),
                Value<String> evolvedPersonality = const Value.absent(),
                Value<String> evolvedScenario = const Value.absent(),
                Value<int> evolutionCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
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
                memorySources: memorySources,
                evolvedPersonality: evolvedPersonality,
                evolvedScenario: evolvedScenario,
                evolutionCount: evolutionCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
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
                Value<String?> folderId = const Value.absent(),
                Value<String?> lorebook = const Value.absent(),
                Value<String> worldNames = const Value.absent(),
                Value<String> memorySources = const Value.absent(),
                Value<String> evolvedPersonality = const Value.absent(),
                Value<String> evolvedScenario = const Value.absent(),
                Value<int> evolutionCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
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
                memorySources: memorySources,
                evolvedPersonality: evolvedPersonality,
                evolvedScenario: evolvedScenario,
                evolutionCount: evolutionCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
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
      (Character, BaseReferences<_$AppDatabase, $CharactersTable, Character>),
      Character,
      PrefetchHooks Function()
    >;
typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      required String id,
      Value<String?> characterId,
      Value<String?> groupId,
      Value<String?> name,
      Value<String?> description,
      Value<String> authorNote,
      Value<int> authorNoteDepth,
      Value<String?> summary,
      Value<int?> summaryLastIndex,
      Value<String?> parentSession,
      Value<int?> forkIndex,
      Value<int> affectionScore,
      Value<int> relationshipTier,
      Value<bool> realismEnabled,
      Value<int> shortTermMood,
      Value<int> moodDecayCounter,
      Value<String> characterEmotion,
      Value<String> emotionIntensity,
      Value<String> timeOfDay,
      Value<int> dayCount,
      Value<bool> nsfwCooldownEnabled,
      Value<int> arousalLevel,
      Value<int> cooldownTurnsRemaining,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<String> id,
      Value<String?> characterId,
      Value<String?> groupId,
      Value<String?> name,
      Value<String?> description,
      Value<String> authorNote,
      Value<int> authorNoteDepth,
      Value<String?> summary,
      Value<int?> summaryLastIndex,
      Value<String?> parentSession,
      Value<int?> forkIndex,
      Value<int> affectionScore,
      Value<int> relationshipTier,
      Value<bool> realismEnabled,
      Value<int> shortTermMood,
      Value<int> moodDecayCounter,
      Value<String> characterEmotion,
      Value<String> emotionIntensity,
      Value<String> timeOfDay,
      Value<int> dayCount,
      Value<bool> nsfwCooldownEnabled,
      Value<int> arousalLevel,
      Value<int> cooldownTurnsRemaining,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

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

  ColumnFilters<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
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

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get summaryLastIndex => $composableBuilder(
    column: $table.summaryLastIndex,
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

  ColumnFilters<int> get affectionScore => $composableBuilder(
    column: $table.affectionScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get relationshipTier => $composableBuilder(
    column: $table.relationshipTier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get realismEnabled => $composableBuilder(
    column: $table.realismEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shortTermMood => $composableBuilder(
    column: $table.shortTermMood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get moodDecayCounter => $composableBuilder(
    column: $table.moodDecayCounter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get characterEmotion => $composableBuilder(
    column: $table.characterEmotion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emotionIntensity => $composableBuilder(
    column: $table.emotionIntensity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeOfDay => $composableBuilder(
    column: $table.timeOfDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayCount => $composableBuilder(
    column: $table.dayCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get nsfwCooldownEnabled => $composableBuilder(
    column: $table.nsfwCooldownEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get arousalLevel => $composableBuilder(
    column: $table.arousalLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cooldownTurnsRemaining => $composableBuilder(
    column: $table.cooldownTurnsRemaining,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
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

  ColumnOrderings<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
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

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get summaryLastIndex => $composableBuilder(
    column: $table.summaryLastIndex,
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

  ColumnOrderings<int> get affectionScore => $composableBuilder(
    column: $table.affectionScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get relationshipTier => $composableBuilder(
    column: $table.relationshipTier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get realismEnabled => $composableBuilder(
    column: $table.realismEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shortTermMood => $composableBuilder(
    column: $table.shortTermMood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get moodDecayCounter => $composableBuilder(
    column: $table.moodDecayCounter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get characterEmotion => $composableBuilder(
    column: $table.characterEmotion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emotionIntensity => $composableBuilder(
    column: $table.emotionIntensity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeOfDay => $composableBuilder(
    column: $table.timeOfDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayCount => $composableBuilder(
    column: $table.dayCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get nsfwCooldownEnabled => $composableBuilder(
    column: $table.nsfwCooldownEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get arousalLevel => $composableBuilder(
    column: $table.arousalLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cooldownTurnsRemaining => $composableBuilder(
    column: $table.cooldownTurnsRemaining,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
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

  GeneratedColumn<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

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

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<int> get summaryLastIndex => $composableBuilder(
    column: $table.summaryLastIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentSession => $composableBuilder(
    column: $table.parentSession,
    builder: (column) => column,
  );

  GeneratedColumn<int> get forkIndex =>
      $composableBuilder(column: $table.forkIndex, builder: (column) => column);

  GeneratedColumn<int> get affectionScore => $composableBuilder(
    column: $table.affectionScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get relationshipTier => $composableBuilder(
    column: $table.relationshipTier,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get realismEnabled => $composableBuilder(
    column: $table.realismEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get shortTermMood => $composableBuilder(
    column: $table.shortTermMood,
    builder: (column) => column,
  );

  GeneratedColumn<int> get moodDecayCounter => $composableBuilder(
    column: $table.moodDecayCounter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get characterEmotion => $composableBuilder(
    column: $table.characterEmotion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get emotionIntensity => $composableBuilder(
    column: $table.emotionIntensity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timeOfDay =>
      $composableBuilder(column: $table.timeOfDay, builder: (column) => column);

  GeneratedColumn<int> get dayCount =>
      $composableBuilder(column: $table.dayCount, builder: (column) => column);

  GeneratedColumn<bool> get nsfwCooldownEnabled => $composableBuilder(
    column: $table.nsfwCooldownEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get arousalLevel => $composableBuilder(
    column: $table.arousalLevel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cooldownTurnsRemaining => $composableBuilder(
    column: $table.cooldownTurnsRemaining,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
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
          (Session, BaseReferences<_$AppDatabase, $SessionsTable, Session>),
          Session,
          PrefetchHooks Function()
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
                Value<String?> characterId = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> authorNote = const Value.absent(),
                Value<int> authorNoteDepth = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<int?> summaryLastIndex = const Value.absent(),
                Value<String?> parentSession = const Value.absent(),
                Value<int?> forkIndex = const Value.absent(),
                Value<int> affectionScore = const Value.absent(),
                Value<int> relationshipTier = const Value.absent(),
                Value<bool> realismEnabled = const Value.absent(),
                Value<int> shortTermMood = const Value.absent(),
                Value<int> moodDecayCounter = const Value.absent(),
                Value<String> characterEmotion = const Value.absent(),
                Value<String> emotionIntensity = const Value.absent(),
                Value<String> timeOfDay = const Value.absent(),
                Value<int> dayCount = const Value.absent(),
                Value<bool> nsfwCooldownEnabled = const Value.absent(),
                Value<int> arousalLevel = const Value.absent(),
                Value<int> cooldownTurnsRemaining = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                characterId: characterId,
                groupId: groupId,
                name: name,
                description: description,
                authorNote: authorNote,
                authorNoteDepth: authorNoteDepth,
                summary: summary,
                summaryLastIndex: summaryLastIndex,
                parentSession: parentSession,
                forkIndex: forkIndex,
                affectionScore: affectionScore,
                relationshipTier: relationshipTier,
                realismEnabled: realismEnabled,
                shortTermMood: shortTermMood,
                moodDecayCounter: moodDecayCounter,
                characterEmotion: characterEmotion,
                emotionIntensity: emotionIntensity,
                timeOfDay: timeOfDay,
                dayCount: dayCount,
                nsfwCooldownEnabled: nsfwCooldownEnabled,
                arousalLevel: arousalLevel,
                cooldownTurnsRemaining: cooldownTurnsRemaining,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> characterId = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> authorNote = const Value.absent(),
                Value<int> authorNoteDepth = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<int?> summaryLastIndex = const Value.absent(),
                Value<String?> parentSession = const Value.absent(),
                Value<int?> forkIndex = const Value.absent(),
                Value<int> affectionScore = const Value.absent(),
                Value<int> relationshipTier = const Value.absent(),
                Value<bool> realismEnabled = const Value.absent(),
                Value<int> shortTermMood = const Value.absent(),
                Value<int> moodDecayCounter = const Value.absent(),
                Value<String> characterEmotion = const Value.absent(),
                Value<String> emotionIntensity = const Value.absent(),
                Value<String> timeOfDay = const Value.absent(),
                Value<int> dayCount = const Value.absent(),
                Value<bool> nsfwCooldownEnabled = const Value.absent(),
                Value<int> arousalLevel = const Value.absent(),
                Value<int> cooldownTurnsRemaining = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                characterId: characterId,
                groupId: groupId,
                name: name,
                description: description,
                authorNote: authorNote,
                authorNoteDepth: authorNoteDepth,
                summary: summary,
                summaryLastIndex: summaryLastIndex,
                parentSession: parentSession,
                forkIndex: forkIndex,
                affectionScore: affectionScore,
                relationshipTier: relationshipTier,
                realismEnabled: realismEnabled,
                shortTermMood: shortTermMood,
                moodDecayCounter: moodDecayCounter,
                characterEmotion: characterEmotion,
                emotionIntensity: emotionIntensity,
                timeOfDay: timeOfDay,
                dayCount: dayCount,
                nsfwCooldownEnabled: nsfwCooldownEnabled,
                arousalLevel: arousalLevel,
                cooldownTurnsRemaining: cooldownTurnsRemaining,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
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
      (Session, BaseReferences<_$AppDatabase, $SessionsTable, Session>),
      Session,
      PrefetchHooks Function()
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String sessionId,
      required int position,
      required String sender,
      required bool isUser,
      Value<String?> characterId,
      Value<String> swipes,
      Value<int> swipeIndex,
      Value<String> swipeDurations,
      Value<String?> metadata,
      Value<String?> swipeMetadata,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<int> position,
      Value<String> sender,
      Value<bool> isUser,
      Value<String?> characterId,
      Value<String> swipes,
      Value<int> swipeIndex,
      Value<String> swipeDurations,
      Value<String?> metadata,
      Value<String?> swipeMetadata,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
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

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
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

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get swipeMetadata => $composableBuilder(
    column: $table.swipeMetadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
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
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
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

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get swipeMetadata => $composableBuilder(
    column: $table.swipeMetadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
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
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

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

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<String> get swipeMetadata => $composableBuilder(
    column: $table.swipeMetadata,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
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
          (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
          Message,
          PrefetchHooks Function()
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
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> sender = const Value.absent(),
                Value<bool> isUser = const Value.absent(),
                Value<String?> characterId = const Value.absent(),
                Value<String> swipes = const Value.absent(),
                Value<int> swipeIndex = const Value.absent(),
                Value<String> swipeDurations = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<String?> swipeMetadata = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
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
                metadata: metadata,
                swipeMetadata: swipeMetadata,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required int position,
                required String sender,
                required bool isUser,
                Value<String?> characterId = const Value.absent(),
                Value<String> swipes = const Value.absent(),
                Value<int> swipeIndex = const Value.absent(),
                Value<String> swipeDurations = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<String?> swipeMetadata = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
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
                metadata: metadata,
                swipeMetadata: swipeMetadata,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
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
      (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
      Message,
      PrefetchHooks Function()
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
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
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
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
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
          (Group, BaseReferences<_$AppDatabase, $GroupsTable, Group>),
          Group,
          PrefetchHooks Function()
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
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
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
                updatedAt: updatedAt,
                deletedAt: deletedAt,
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
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
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
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
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
      (Group, BaseReferences<_$AppDatabase, $GroupsTable, Group>),
      Group,
      PrefetchHooks Function()
    >;
typedef $$FoldersTableCreateCompanionBuilder =
    FoldersCompanion Function({
      required String id,
      required String name,
      Value<String?> parentId,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$FoldersTableUpdateCompanionBuilder =
    FoldersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> parentId,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
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

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
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
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
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
          (Folder, BaseReferences<_$AppDatabase, $FoldersTable, Folder>),
          Folder,
          PrefetchHooks Function()
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
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                name: name,
                parentId: parentId,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> parentId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                name: name,
                parentId: parentId,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
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
      (Folder, BaseReferences<_$AppDatabase, $FoldersTable, Folder>),
      Folder,
      PrefetchHooks Function()
    >;
typedef $$PersonasTableCreateCompanionBuilder =
    PersonasCompanion Function({
      required String id,
      Value<String> title,
      Value<String> name,
      Value<String> description,
      Value<String> persona,
      Value<String> learnedFacts,
      Value<String?> avatarPath,
      Value<bool> isActive,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$PersonasTableUpdateCompanionBuilder =
    PersonasCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> name,
      Value<String> description,
      Value<String> persona,
      Value<String> learnedFacts,
      Value<String?> avatarPath,
      Value<bool> isActive,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
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

  ColumnFilters<String> get learnedFacts => $composableBuilder(
    column: $table.learnedFacts,
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  ColumnOrderings<String> get learnedFacts => $composableBuilder(
    column: $table.learnedFacts,
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  GeneratedColumn<String> get learnedFacts => $composableBuilder(
    column: $table.learnedFacts,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
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
                Value<String> learnedFacts = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonasCompanion(
                id: id,
                title: title,
                name: name,
                description: description,
                persona: persona,
                learnedFacts: learnedFacts,
                avatarPath: avatarPath,
                isActive: isActive,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> persona = const Value.absent(),
                Value<String> learnedFacts = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonasCompanion.insert(
                id: id,
                title: title,
                name: name,
                description: description,
                persona: persona,
                learnedFacts: learnedFacts,
                avatarPath: avatarPath,
                isActive: isActive,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
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
      required String id,
      required String name,
      Value<String> description,
      Value<String?> lorebook,
      Value<String?> linkedCharacterName,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$WorldsTableUpdateCompanionBuilder =
    WorldsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> description,
      Value<String?> lorebook,
      Value<String?> linkedCharacterName,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
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

  ColumnFilters<String> get lorebook => $composableBuilder(
    column: $table.lorebook,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedCharacterName => $composableBuilder(
    column: $table.linkedCharacterName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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

  ColumnOrderings<String> get lorebook => $composableBuilder(
    column: $table.lorebook,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedCharacterName => $composableBuilder(
    column: $table.linkedCharacterName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
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
  GeneratedColumn<String> get id =>
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

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
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
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> lorebook = const Value.absent(),
                Value<String?> linkedCharacterName = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorldsCompanion(
                id: id,
                name: name,
                description: description,
                lorebook: lorebook,
                linkedCharacterName: linkedCharacterName,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> description = const Value.absent(),
                Value<String?> lorebook = const Value.absent(),
                Value<String?> linkedCharacterName = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorldsCompanion.insert(
                id: id,
                name: name,
                description: description,
                lorebook: lorebook,
                linkedCharacterName: linkedCharacterName,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
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
typedef $$MessageEmbeddingsTableCreateCompanionBuilder =
    MessageEmbeddingsCompanion Function({
      required String id,
      required String sessionId,
      Value<String?> characterId,
      required int positionStart,
      required int positionEnd,
      required String content,
      required Uint8List embedding,
      required int dimensions,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$MessageEmbeddingsTableUpdateCompanionBuilder =
    MessageEmbeddingsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String?> characterId,
      Value<int> positionStart,
      Value<int> positionEnd,
      Value<String> content,
      Value<Uint8List> embedding,
      Value<int> dimensions,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$MessageEmbeddingsTableFilterComposer
    extends Composer<_$AppDatabase, $MessageEmbeddingsTable> {
  $$MessageEmbeddingsTableFilterComposer({
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

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionStart => $composableBuilder(
    column: $table.positionStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionEnd => $composableBuilder(
    column: $table.positionEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessageEmbeddingsTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageEmbeddingsTable> {
  $$MessageEmbeddingsTableOrderingComposer({
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

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionStart => $composableBuilder(
    column: $table.positionStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionEnd => $composableBuilder(
    column: $table.positionEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessageEmbeddingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageEmbeddingsTable> {
  $$MessageEmbeddingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionStart => $composableBuilder(
    column: $table.positionStart,
    builder: (column) => column,
  );

  GeneratedColumn<int> get positionEnd => $composableBuilder(
    column: $table.positionEnd,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MessageEmbeddingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageEmbeddingsTable,
          MessageEmbedding,
          $$MessageEmbeddingsTableFilterComposer,
          $$MessageEmbeddingsTableOrderingComposer,
          $$MessageEmbeddingsTableAnnotationComposer,
          $$MessageEmbeddingsTableCreateCompanionBuilder,
          $$MessageEmbeddingsTableUpdateCompanionBuilder,
          (
            MessageEmbedding,
            BaseReferences<
              _$AppDatabase,
              $MessageEmbeddingsTable,
              MessageEmbedding
            >,
          ),
          MessageEmbedding,
          PrefetchHooks Function()
        > {
  $$MessageEmbeddingsTableTableManager(
    _$AppDatabase db,
    $MessageEmbeddingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageEmbeddingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageEmbeddingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageEmbeddingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String?> characterId = const Value.absent(),
                Value<int> positionStart = const Value.absent(),
                Value<int> positionEnd = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<Uint8List> embedding = const Value.absent(),
                Value<int> dimensions = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageEmbeddingsCompanion(
                id: id,
                sessionId: sessionId,
                characterId: characterId,
                positionStart: positionStart,
                positionEnd: positionEnd,
                content: content,
                embedding: embedding,
                dimensions: dimensions,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                Value<String?> characterId = const Value.absent(),
                required int positionStart,
                required int positionEnd,
                required String content,
                required Uint8List embedding,
                required int dimensions,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageEmbeddingsCompanion.insert(
                id: id,
                sessionId: sessionId,
                characterId: characterId,
                positionStart: positionStart,
                positionEnd: positionEnd,
                content: content,
                embedding: embedding,
                dimensions: dimensions,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessageEmbeddingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageEmbeddingsTable,
      MessageEmbedding,
      $$MessageEmbeddingsTableFilterComposer,
      $$MessageEmbeddingsTableOrderingComposer,
      $$MessageEmbeddingsTableAnnotationComposer,
      $$MessageEmbeddingsTableCreateCompanionBuilder,
      $$MessageEmbeddingsTableUpdateCompanionBuilder,
      (
        MessageEmbedding,
        BaseReferences<
          _$AppDatabase,
          $MessageEmbeddingsTable,
          MessageEmbedding
        >,
      ),
      MessageEmbedding,
      PrefetchHooks Function()
    >;
typedef $$DataBankEntriesTableCreateCompanionBuilder =
    DataBankEntriesCompanion Function({
      required String id,
      required String characterId,
      required String title,
      required String content,
      Value<Uint8List?> embedding,
      Value<int> dimensions,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$DataBankEntriesTableUpdateCompanionBuilder =
    DataBankEntriesCompanion Function({
      Value<String> id,
      Value<String> characterId,
      Value<String> title,
      Value<String> content,
      Value<Uint8List?> embedding,
      Value<int> dimensions,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$DataBankEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DataBankEntriesTable> {
  $$DataBankEntriesTableFilterComposer({
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

  ColumnFilters<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DataBankEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DataBankEntriesTable> {
  $$DataBankEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DataBankEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DataBankEntriesTable> {
  $$DataBankEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DataBankEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DataBankEntriesTable,
          DataBankEntry,
          $$DataBankEntriesTableFilterComposer,
          $$DataBankEntriesTableOrderingComposer,
          $$DataBankEntriesTableAnnotationComposer,
          $$DataBankEntriesTableCreateCompanionBuilder,
          $$DataBankEntriesTableUpdateCompanionBuilder,
          (
            DataBankEntry,
            BaseReferences<_$AppDatabase, $DataBankEntriesTable, DataBankEntry>,
          ),
          DataBankEntry,
          PrefetchHooks Function()
        > {
  $$DataBankEntriesTableTableManager(
    _$AppDatabase db,
    $DataBankEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DataBankEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DataBankEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DataBankEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> characterId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<Uint8List?> embedding = const Value.absent(),
                Value<int> dimensions = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DataBankEntriesCompanion(
                id: id,
                characterId: characterId,
                title: title,
                content: content,
                embedding: embedding,
                dimensions: dimensions,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String characterId,
                required String title,
                required String content,
                Value<Uint8List?> embedding = const Value.absent(),
                Value<int> dimensions = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DataBankEntriesCompanion.insert(
                id: id,
                characterId: characterId,
                title: title,
                content: content,
                embedding: embedding,
                dimensions: dimensions,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DataBankEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DataBankEntriesTable,
      DataBankEntry,
      $$DataBankEntriesTableFilterComposer,
      $$DataBankEntriesTableOrderingComposer,
      $$DataBankEntriesTableAnnotationComposer,
      $$DataBankEntriesTableCreateCompanionBuilder,
      $$DataBankEntriesTableUpdateCompanionBuilder,
      (
        DataBankEntry,
        BaseReferences<_$AppDatabase, $DataBankEntriesTable, DataBankEntry>,
      ),
      DataBankEntry,
      PrefetchHooks Function()
    >;
typedef $$ObjectivesTableCreateCompanionBuilder =
    ObjectivesCompanion Function({
      required String id,
      required String characterId,
      required String objective,
      Value<String> tasks,
      Value<bool> active,
      Value<int> checkFrequency,
      Value<int> injectionDepth,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$ObjectivesTableUpdateCompanionBuilder =
    ObjectivesCompanion Function({
      Value<String> id,
      Value<String> characterId,
      Value<String> objective,
      Value<String> tasks,
      Value<bool> active,
      Value<int> checkFrequency,
      Value<int> injectionDepth,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ObjectivesTableFilterComposer
    extends Composer<_$AppDatabase, $ObjectivesTable> {
  $$ObjectivesTableFilterComposer({
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

  ColumnFilters<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objective => $composableBuilder(
    column: $table.objective,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tasks => $composableBuilder(
    column: $table.tasks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkFrequency => $composableBuilder(
    column: $table.checkFrequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get injectionDepth => $composableBuilder(
    column: $table.injectionDepth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ObjectivesTableOrderingComposer
    extends Composer<_$AppDatabase, $ObjectivesTable> {
  $$ObjectivesTableOrderingComposer({
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

  ColumnOrderings<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objective => $composableBuilder(
    column: $table.objective,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tasks => $composableBuilder(
    column: $table.tasks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkFrequency => $composableBuilder(
    column: $table.checkFrequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get injectionDepth => $composableBuilder(
    column: $table.injectionDepth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ObjectivesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ObjectivesTable> {
  $$ObjectivesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get characterId => $composableBuilder(
    column: $table.characterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get objective =>
      $composableBuilder(column: $table.objective, builder: (column) => column);

  GeneratedColumn<String> get tasks =>
      $composableBuilder(column: $table.tasks, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<int> get checkFrequency => $composableBuilder(
    column: $table.checkFrequency,
    builder: (column) => column,
  );

  GeneratedColumn<int> get injectionDepth => $composableBuilder(
    column: $table.injectionDepth,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ObjectivesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ObjectivesTable,
          Objective,
          $$ObjectivesTableFilterComposer,
          $$ObjectivesTableOrderingComposer,
          $$ObjectivesTableAnnotationComposer,
          $$ObjectivesTableCreateCompanionBuilder,
          $$ObjectivesTableUpdateCompanionBuilder,
          (
            Objective,
            BaseReferences<_$AppDatabase, $ObjectivesTable, Objective>,
          ),
          Objective,
          PrefetchHooks Function()
        > {
  $$ObjectivesTableTableManager(_$AppDatabase db, $ObjectivesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ObjectivesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ObjectivesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ObjectivesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> characterId = const Value.absent(),
                Value<String> objective = const Value.absent(),
                Value<String> tasks = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> checkFrequency = const Value.absent(),
                Value<int> injectionDepth = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ObjectivesCompanion(
                id: id,
                characterId: characterId,
                objective: objective,
                tasks: tasks,
                active: active,
                checkFrequency: checkFrequency,
                injectionDepth: injectionDepth,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String characterId,
                required String objective,
                Value<String> tasks = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> checkFrequency = const Value.absent(),
                Value<int> injectionDepth = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ObjectivesCompanion.insert(
                id: id,
                characterId: characterId,
                objective: objective,
                tasks: tasks,
                active: active,
                checkFrequency: checkFrequency,
                injectionDepth: injectionDepth,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ObjectivesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ObjectivesTable,
      Objective,
      $$ObjectivesTableFilterComposer,
      $$ObjectivesTableOrderingComposer,
      $$ObjectivesTableAnnotationComposer,
      $$ObjectivesTableCreateCompanionBuilder,
      $$ObjectivesTableUpdateCompanionBuilder,
      (Objective, BaseReferences<_$AppDatabase, $ObjectivesTable, Objective>),
      Objective,
      PrefetchHooks Function()
    >;
typedef $$StoryProjectsTableCreateCompanionBuilder =
    StoryProjectsCompanion Function({
      required String id,
      Value<String> title,
      required String data,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$StoryProjectsTableUpdateCompanionBuilder =
    StoryProjectsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> data,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$StoryProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $StoryProjectsTable> {
  $$StoryProjectsTableFilterComposer({
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

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoryProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $StoryProjectsTable> {
  $$StoryProjectsTableOrderingComposer({
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

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoryProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoryProjectsTable> {
  $$StoryProjectsTableAnnotationComposer({
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

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$StoryProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoryProjectsTable,
          StoryProject,
          $$StoryProjectsTableFilterComposer,
          $$StoryProjectsTableOrderingComposer,
          $$StoryProjectsTableAnnotationComposer,
          $$StoryProjectsTableCreateCompanionBuilder,
          $$StoryProjectsTableUpdateCompanionBuilder,
          (
            StoryProject,
            BaseReferences<_$AppDatabase, $StoryProjectsTable, StoryProject>,
          ),
          StoryProject,
          PrefetchHooks Function()
        > {
  $$StoryProjectsTableTableManager(_$AppDatabase db, $StoryProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoryProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoryProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoryProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoryProjectsCompanion(
                id: id,
                title: title,
                data: data,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                required String data,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoryProjectsCompanion.insert(
                id: id,
                title: title,
                data: data,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoryProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoryProjectsTable,
      StoryProject,
      $$StoryProjectsTableFilterComposer,
      $$StoryProjectsTableOrderingComposer,
      $$StoryProjectsTableAnnotationComposer,
      $$StoryProjectsTableCreateCompanionBuilder,
      $$StoryProjectsTableUpdateCompanionBuilder,
      (
        StoryProject,
        BaseReferences<_$AppDatabase, $StoryProjectsTable, StoryProject>,
      ),
      StoryProject,
      PrefetchHooks Function()
    >;
typedef $$SyncMetaTableCreateCompanionBuilder =
    SyncMetaCompanion Function({
      Value<int> id,
      Value<int> version,
      Value<DateTime> lastModifiedAt,
    });
typedef $$SyncMetaTableUpdateCompanionBuilder =
    SyncMetaCompanion Function({
      Value<int> id,
      Value<int> version,
      Value<DateTime> lastModifiedAt,
    });

class $$SyncMetaTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
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

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastModifiedAt => $composableBuilder(
    column: $table.lastModifiedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
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

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastModifiedAt => $composableBuilder(
    column: $table.lastModifiedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get lastModifiedAt => $composableBuilder(
    column: $table.lastModifiedAt,
    builder: (column) => column,
  );
}

class $$SyncMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetaTable,
          SyncMetaData,
          $$SyncMetaTableFilterComposer,
          $$SyncMetaTableOrderingComposer,
          $$SyncMetaTableAnnotationComposer,
          $$SyncMetaTableCreateCompanionBuilder,
          $$SyncMetaTableUpdateCompanionBuilder,
          (
            SyncMetaData,
            BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaData>,
          ),
          SyncMetaData,
          PrefetchHooks Function()
        > {
  $$SyncMetaTableTableManager(_$AppDatabase db, $SyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> lastModifiedAt = const Value.absent(),
              }) => SyncMetaCompanion(
                id: id,
                version: version,
                lastModifiedAt: lastModifiedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> lastModifiedAt = const Value.absent(),
              }) => SyncMetaCompanion.insert(
                id: id,
                version: version,
                lastModifiedAt: lastModifiedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetaTable,
      SyncMetaData,
      $$SyncMetaTableFilterComposer,
      $$SyncMetaTableOrderingComposer,
      $$SyncMetaTableAnnotationComposer,
      $$SyncMetaTableCreateCompanionBuilder,
      $$SyncMetaTableUpdateCompanionBuilder,
      (
        SyncMetaData,
        BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaData>,
      ),
      SyncMetaData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CharactersTableTableManager get characters =>
      $$CharactersTableTableManager(_db, _db.characters);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db, _db.groups);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$PersonasTableTableManager get personas =>
      $$PersonasTableTableManager(_db, _db.personas);
  $$WorldsTableTableManager get worlds =>
      $$WorldsTableTableManager(_db, _db.worlds);
  $$MessageEmbeddingsTableTableManager get messageEmbeddings =>
      $$MessageEmbeddingsTableTableManager(_db, _db.messageEmbeddings);
  $$DataBankEntriesTableTableManager get dataBankEntries =>
      $$DataBankEntriesTableTableManager(_db, _db.dataBankEntries);
  $$ObjectivesTableTableManager get objectives =>
      $$ObjectivesTableTableManager(_db, _db.objectives);
  $$StoryProjectsTableTableManager get storyProjects =>
      $$StoryProjectsTableTableManager(_db, _db.storyProjects);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
}
