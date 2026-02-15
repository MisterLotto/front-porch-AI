import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPersona {
  final String name;
  final String description;
  final String persona;

  UserPersona({
    this.name = 'User',
    this.description = '',
    this.persona = '',
  });

  UserPersona copyWith({
    String? name,
    String? description,
    String? persona,
  }) {
    return UserPersona(
      name: name ?? this.name,
      description: description ?? this.description,
      persona: persona ?? this.persona,
    );
  }
}

class UserPersonaService extends ChangeNotifier {
  UserPersona _persona = UserPersona();
  
  UserPersona get persona => _persona;

  UserPersonaService() {
    _loadPersona();
  }

  Future<void> _loadPersona() async {
    final prefs = await SharedPreferences.getInstance();
    _persona = UserPersona(
      name: prefs.getString('user_name') ?? 'User',
      description: prefs.getString('user_description') ?? '',
      persona: prefs.getString('user_persona') ?? '',
    );
    notifyListeners();
  }

  Future<void> updatePersona(UserPersona newPersona) async {
    _persona = newPersona;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _persona.name);
    await prefs.setString('user_description', _persona.description);
    await prefs.setString('user_persona', _persona.persona);
    notifyListeners();
  }
}
