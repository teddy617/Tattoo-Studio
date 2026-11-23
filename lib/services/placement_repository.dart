import 'dart:convert';
import 'dart:io';

import 'project_repository.dart';

/// Per-project 3D preview settings, stored separately from the design.
class PlacementRepository {
  final ProjectRepository _projects = ProjectRepository();

  Future<Map<String, dynamic>?> read(String projectId) async {
    final directory = await _projects.projectDirectory(projectId);
    final file = File('${directory.path}/placement.json');
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic> || json['schemaVersion'] != 1) {
        return null;
      }
      return json;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String projectId, Map<String, dynamic> state) async {
    final directory = await _projects.projectDirectory(projectId);
    final destination = File('${directory.path}/placement.json');
    final temporary = File('${directory.path}/placement.tmp');
    await temporary.writeAsString(jsonEncode({
      'schemaVersion': 1,
      'modelVersion': 'anatomy-mainbody-v2',
      ...state,
    }), flush: true);
    await temporary.rename(destination.path);
  }
}
