import 'package:flutter/material.dart';

import '../models/design_project.dart';
import '../services/project_repository.dart';
import 'editor_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final ProjectRepository _repository = ProjectRepository();
  List<DesignProject> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final projects = await _repository.listProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read projects: $error')),
      );
    }
  }

  Future<void> _open(DesignProject project) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(project: project)),
    );
    await _refresh();
  }

  Future<void> _newProject() async {
    try {
      final project = await _repository.createProject();
      if (!mounted) return;
      await _open(project);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create project: $error')),
        );
      }
    }
  }

  Future<void> _delete(DesignProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete design?'),
        content: Text('Delete "${project.name}" and its imported artwork?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteProject(project.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tattoo Studio')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _newProject,
          icon: const Icon(Icons.add),
          label: const Text('New design'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _projects.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.layers_outlined, size: 64),
                          const SizedBox(height: 16),
                          Text('Your design studio',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 10),
                          const Text(
                            'Start a project, import tattoo artwork, and turn '
                            'individual designs into editable layers.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _newProject,
                            icon: const Icon(Icons.add),
                            label: const Text('Create first design'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
                      itemCount: _projects.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final project = _projects[index];
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.brush_outlined),
                            ),
                            title: Text(project.name),
                            subtitle: Text('${project.layers.length} layers'),
                            onTap: () => _open(project),
                            trailing: IconButton(
                              tooltip: 'Delete project',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(project),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      );
}
