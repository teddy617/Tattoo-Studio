import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/design_project.dart';

class ProjectRepository {
  Future<Directory> get _root async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/tattoo_studio/projects')..createSync(recursive: true);
  }

  Future<Directory> projectDirectory(String projectId) async {
    final root = await _root;
    return Directory('${root.path}/$projectId')..createSync(recursive: true);
  }

  Future<DesignProject> createProject() async {
    final now = DateTime.now();
    final project = DesignProject(
      id: makeId(),
      name: 'Untitled design',
      updatedAt: now,
      layers: [],
    );
    await save(project);
    return project;
  }

  Future<void> save(DesignProject project) async {
    final directory = await projectDirectory(project.id);
    // Write to a temporary file first to reduce corruption on interruption.
    final temp = File('${directory.path}/project.tmp');
    final destination = File('${directory.path}/project.json');
    await temp.writeAsString(jsonEncode(project.toJson()), flush: true);
    // Android/iOS use POSIX rename, replacing the existing project atomically.
    await temp.rename(destination.path);
  }

  Future<List<DesignProject>> listProjects() async {
    final root = await _root;
    final projects = <DesignProject>[];
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final file = File('${entity.path}/project.json');
      if (!await file.exists()) continue;
      try {
        projects.add(DesignProject.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>,
        ));
      } catch (_) {
        // Keep broken files on disk for recovery instead of deleting them.
      }
    }
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  Future<Uint8List> readAsset(String projectId, String assetPath) async {
    final project = await projectDirectory(projectId);
    return File('${project.path}/$assetPath').readAsBytes();
  }

  Future<String> writeLayerAsset(
    String projectId,
    String layerId,
    Uint8List bytes,
  ) async {
    final project = await projectDirectory(projectId);
    final assets = Directory('${project.path}/assets');
    await assets.create(recursive: true);
    await File('${assets.path}/$layerId.png').writeAsBytes(bytes, flush: true);
    return 'assets/$layerId.png';
  }

  Future<void> deleteProject(String id) async {
    final directory = await projectDirectory(id);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<File> writeExport(String projectId, Uint8List bytes) async {
    final docs = await getApplicationDocumentsDirectory();
    final directory = Directory('${docs.path}/tattoo_studio/exports');
    await directory.create(recursive: true);
    final filename = 'tattoo_${DateTime.now().millisecondsSinceEpoch}.png';
    return File('${directory.path}/$filename').writeAsBytes(bytes, flush: true);
  }
}
