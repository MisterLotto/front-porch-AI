import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kobold_character_card_manager/services/model_manager.dart';

class ModelManagerPage extends StatefulWidget {
  const ModelManagerPage({super.key});

  @override
  State<ModelManagerPage> createState() => _ModelManagerPageState();
}

class _ModelManagerPageState extends State<ModelManagerPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Refresh models on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ModelManager>(context, listen: false).refreshModels();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    if (_searchController.text.trim().isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final results = await Provider.of<ModelManager>(context, listen: false).searchHFModels(_searchController.text);
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch(e) {
      if (mounted) {
         setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }
  }

  void _showDownloadDialog(Map<String, dynamic> modelData) async {
    final repoId = modelData['id'] ?? modelData['modelId'] ?? '';
    if (repoId.isEmpty) return;

    // Show loading dialog while fetching file tree
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final files = await Provider.of<ModelManager>(context, listen: false).getModelFiles(repoId);
    
    if (!mounted) return;
    Navigator.pop(context); // Close loading

    if (files.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No .gguf files found in this repo.')));
      }
      return;
    }

    if (!mounted) return;
    
    // Show file selection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Select File to Download', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 600,
          height: 400,
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final sizeMb = (double.tryParse(file['size'] ?? '0') ?? 0) / (1024 * 1024);
              final filename = file['filename']!;
              final url = file['url']!;
              
              return ListTile(
                title: Text(filename, style: const TextStyle(color: Colors.white)),
                subtitle: Text('${sizeMb.toStringAsFixed(2)} MB', style: const TextStyle(color: Colors.white70)),
                trailing: IconButton(
                  icon: const Icon(Icons.download, color: Colors.blueAccent),
                  onPressed: () {
                    Navigator.pop(context);
                    _startDownload(url, filename.split('/').last);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _startDownload(String url, String filename) {
    Provider.of<ModelManager>(context, listen: false).downloadModel(url, filename).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    });
  }

  void _confirmDelete(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Model?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete ${path.split(Platform.pathSeparator).last}?', 
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
               Provider.of<ModelManager>(context, listen: false).deleteModel(path);
               Navigator.pop(context);
            },
            child: const Text('Delete', style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _importLocalModel(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gguf'],
      dialogTitle: 'Select a GGUF Model to Import',
    );

    if (result != null && result.files.single.path != null) {
      if (!context.mounted) return;
      final modelManager = Provider.of<ModelManager>(context, listen: false);
      try {
        await modelManager.importLocalModel(result.files.single.path!);
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Model imported successfully!'), backgroundColor: Colors.green),
           );
        }
      } catch (e) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.redAccent),
           );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final modelManager = Provider.of<ModelManager>(context);

    // If downloading, show comprehensive status at bottom
    final isDownloading = modelManager.isDownloading;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Model Manager'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blueAccent),
            onPressed: () => Provider.of<ModelManager>(context, listen: false).refreshModels(),
            tooltip: 'Scan for new models',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Models'),
            Tab(text: 'Search / Download'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: My Models
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Colors.white.withOpacity(0.05),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Models Folder:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.add_to_drive, size: 16, color: Colors.amberAccent),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Import from Computer',
                                    onPressed: () => _importLocalModel(context),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.folder_open, size: 16, color: Colors.blueAccent),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Open Folder in Explorer',
                                    onPressed: () {
                                      if (Platform.isWindows) {
                                        // Normalize and fix separators for Windows Shell
                                        final normPath = modelManager.modelsPath.replaceAll('/', '\\');
                                        Process.run('explorer.exe', [normPath]);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            modelManager.modelsPath,
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          if (modelManager.statusMessage.contains('Import'))
                             Padding(
                               padding: const EdgeInsets.only(top: 8.0),
                               child: Text(modelManager.statusMessage, style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
                             ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: modelManager.models.isEmpty
                          ? const Center(child: Text('No models discovered in this folder.', style: TextStyle(color: Colors.white54)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: modelManager.models.length,
                              itemBuilder: (context, index) {
                                final file = modelManager.models[index];
                                final filename = file.path.split(Platform.pathSeparator).last;
                                double sizeMb = 0;
                                try {
                                   sizeMb = file.statSync().size / (1024 * 1024);
                                } catch (_) {}
                                
                                return Card(
                                  color: Colors.white.withOpacity(0.05),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: const Icon(Icons.psychology, color: Colors.purpleAccent),
                                    title: Text(filename, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    subtitle: Text('${sizeMb.toStringAsFixed(2)} MB', style: const TextStyle(color: Colors.white54)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      onPressed: () => _confirmDelete(context, file.path),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),

                // Tab 2: Search
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search HuggingFace (e.g. "Mistral 7B")',
                                hintStyle: const TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.search, color: Colors.blueAccent),
                                  onPressed: _performSearch,
                                ),
                              ),
                              onSubmitted: (_) => _performSearch(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _isSearching
                          ? const Center(child: CircularProgressIndicator())
                          : _searchResults.isEmpty
                              ? const Center(child: Text('Search for .gguf models on HuggingFace', style: TextStyle(color: Colors.white30)))
                              : ListView.builder(
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final result = _searchResults[index];
                                    return ListTile(
                                      title: Text(result['id'] ?? result['modelId'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                                      subtitle: Text('Downloads: ${result['downloads'] ?? 0}', style: const TextStyle(color: Colors.white54)),
                                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white30),
                                      onTap: () => _showDownloadDialog(result),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (isDownloading)
            Container(
              color: const Color(0xFF1E293B),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Expanded(
                         child: Text('Downloading: ${modelManager.currentDownload ?? "Unknown"}', 
                           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                       ),
                       if (modelManager.downloadProgress >= 0)
                          Text('${(modelManager.downloadProgress * 100).toStringAsFixed(1)}%', 
                              style: const TextStyle(color: Colors.white70)),
                     ],
                   ),
                   const SizedBox(height: 8),
                   LinearProgressIndicator(value: modelManager.downloadProgress),
                   const SizedBox(height: 4),
                   Text(modelManager.statusMessage, 
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
