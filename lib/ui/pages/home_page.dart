import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kobold_character_card_manager/providers/app_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:path/path.dart' as path; 
import 'package:kobold_character_card_manager/services/character_repository.dart';
import 'package:kobold_character_card_manager/ui/pages/chat_page.dart';
import 'package:kobold_character_card_manager/services/chat_service.dart';
import 'package:kobold_character_card_manager/services/v2_card_service.dart';
import 'package:kobold_character_card_manager/ui/pages/edit_character_page.dart';
import 'package:kobold_character_card_manager/models/character_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterRepository>(
      builder: (context, repo, child) {
        if (repo.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (repo.characters.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Get started by creating a new character!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Provider.of<AppState>(context, listen: false).setIndex(1),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Create New'),
                      style: _buttonStyle(),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _importCharacter(context),
                      icon: const Icon(Icons.download), // Changed to download/import
                      label: const Text('Import Card'),
                      style: _buttonStyle(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => _openBrowser(context),
                      icon: const Icon(Icons.public, color: Colors.blueAccent),
                      label: const Text('AI Character Cards', style: TextStyle(color: Colors.blueAccent)),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () => _showChubWarning(context),
                      icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                      label: const Text('Chub.ai', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
               child: Row(
                 children: [
                   Text('My Characters', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                   const Spacer(),
                   IconButton(
                     tooltip: 'Import Card',
                     icon: const Icon(Icons.download), // Changed to download/import
                     onPressed: () => _importCharacter(context),
                   ),
                   const SizedBox(width: 8),
                   ElevatedButton.icon(
                     onPressed: () => _openBrowser(context),
                     icon: const Icon(Icons.public),
                     label: const Text('AI Cards'),
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                   ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showChubWarning(context),
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('Chub.ai'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                    ),
                 ],
               ),
             ),
             Expanded(
               child: GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            childAspectRatio: 0.7,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
          ),
          itemCount: repo.characters.length,
          itemBuilder: (context, index) {
            final character = repo.characters[index];
            return Card(
              color: Theme.of(context).cardColor,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              ),
              child: Stack( // Changed to Stack for positioning Export button
                children: [
                  InkWell(
                    onTap: () async {
                       final chatService = Provider.of<ChatService>(context, listen: false);
                       await chatService.setActiveCharacter(character);
                       if (context.mounted) {
                         Navigator.of(context).push(
                           MaterialPageRoute(builder: (_) => const ChatPage()),
                         );
                       }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: character.imagePath != null
                              ? Image.file(
                                  File(character.imagePath!),
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.grey.shade800,
                                  child: const Icon(Icons.person, size: 64, color: Colors.white24),
                                ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  character.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Flexible(
                                  child: Text(
                                    character.formattedDescription,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _editCharacter(context, character),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.edit, color: Colors.white, size: 20),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _exportCharacter(context, character),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.upload, color: Colors.white, size: 20),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _confirmDeleteCharacter(context, character),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.delete, color: Colors.redAccent, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
              ),
            ),
          ],
        );
      },
    );
  }

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.white.withOpacity(0.1),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white24),
      ),
    );
  }

  void _confirmDeleteCharacter(BuildContext context, CharacterCard character) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D1111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text(
              'Delete Character',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${character.name}"?\n\nThis will permanently remove the character card and its image file. This action cannot be undone.',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              final repo = Provider.of<CharacterRepository>(context, listen: false);
              await repo.deleteCharacter(character);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${character.name} has been deleted.'),
                    backgroundColor: Colors.red.shade800,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _editCharacter(BuildContext context, CharacterCard character) async {
     await Navigator.push(
       context,
       MaterialPageRoute(builder: (context) => EditCharacterPage(character: character)),
     );
     // Refresh repo after edit
     if (context.mounted) {
       Provider.of<CharacterRepository>(context, listen: false).loadCharacters();
     }
  }

  Future<void> _importCharacter(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'json'],
    );
    
    if (result != null && result.files.single.path != null) {
      if (!context.mounted) return;
      final file = File(result.files.single.path!);
      try {
        await Provider.of<CharacterRepository>(context, listen: false).importCharacter(file);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Character imported successfully!')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
        }
      }
    }
  }

  Future<void> _exportCharacter(BuildContext context, character) async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Character Card',
      fileName: '${character.name}.png',
      type: FileType.custom,
      allowedExtensions: ['png'],
    );

    if (outputFile != null) {
       if (!outputFile.endsWith('.png')) {
         outputFile += '.png';
       }

       try {
         // Use V2CardService to save
         // We need to import it first, but for now assuming it's available via easy access or we inject it
         // Since I cannot easily add imports in this replace block seamlessly without context, 
         // I will assume V2CardService is available or I will add the import in a separate step if missing.
         // Wait, I can't assume. I should have added the import. 
         // I will add the logic here.
         
         // Assuming V2CardService is in services/v2_card_service.dart
         // I'll need to update imports in a separate step if I missed it.
         // For now, let's implement the call.
         final v2Service = Provider.of<V2CardService>(context, listen: false);
         await v2Service.saveCardAsPng(character, outputFile, character.imagePath);

         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to $outputFile')));
         }
       } catch (e) {
         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
         }
       }
    }
  }

  Future<void> _openBrowser(BuildContext context) async {
    // Capture references before async gap so they're available in the callback
    final repo = Provider.of<CharacterRepository>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    
    final webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        title: 'Browse Character Cards',
        titleBarTopPadding: Platform.isMacOS ? 20 : 0,
      ),
    );
    
    // Shared download handler for both platforms
    Future<void> handleDownloadUrl(String url) async {
      debugPrint('AG_DEBUG: Download card intercepted: $url');
      
      try {
        final httpClient = HttpClient();
        final request = await httpClient.getUrl(Uri.parse(url));
        final httpResponse = await request.close();
        
        // Follow redirects and get final response bytes
        final bytes = <int>[];
        await for (final chunk in httpResponse) {
          bytes.addAll(chunk);
        }
        
        httpClient.close();
        
        // Save to characters directory
        final directory = await getApplicationDocumentsDirectory();
        final charDir = Directory('${directory.path}/KoboldManager/Characters');
        if (!await charDir.exists()) {
          await charDir.create(recursive: true);
        }
        
        // Create a filename from the URL or use a timestamp
        final uri = Uri.parse(url);
        String fileName;
        if (uri.pathSegments.isNotEmpty && uri.pathSegments.last.endsWith('.png')) {
          fileName = uri.pathSegments.last;
        } else {
          fileName = 'card_${DateTime.now().millisecondsSinceEpoch}.png';
        }
        final tempFile = File('${charDir.path}/$fileName');
        await tempFile.writeAsBytes(bytes);
        
        // Auto-import the character
        await repo.importCharacter(tempFile);
        
        // Close the webview and show success
        webview.close();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Character card downloaded and imported!'),
            backgroundColor: Colors.green.shade800,
          ),
        );
      } catch (e) {
        debugPrint('AG_DEBUG: Download error: $e');
        messenger.showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
    
    // Platform-specific message handler registration
    if (Platform.isMacOS) {
      // macOS: WKWebView uses registerJavaScriptMessageHandler
      webview.registerJavaScriptMessageHandler('downloadCard', (name, body) async {
        await handleDownloadUrl(body.toString());
      });
    } else if (Platform.isWindows) {
      // Windows: WebView2 uses web message callbacks
      webview.addOnWebMessageReceivedCallback((message) async {
        // Messages prefixed with 'DOWNLOAD:' are download URLs
        if (message.startsWith('DOWNLOAD:')) {
          final url = message.substring('DOWNLOAD:'.length);
          await handleDownloadUrl(url);
        }
      });
    }
    
    // Inject JavaScript to intercept download card links
    // The download button on aicharactercards.com uses URLs like:
    // https://aicharactercards.com/?download_card_image=true&post_id=XXXX
    // Use platform-specific messaging API
    final String jsSendMessage = Platform.isMacOS
        ? 'window.webkit.messageHandlers.downloadCard.postMessage(href)'
        : 'window.chrome.webview.postMessage("DOWNLOAD:" + href)';
    
    webview.addScriptToExecuteOnDocumentCreated('''
      (function() {
        // Intercept clicks on download links
        document.addEventListener('click', function(e) {
          var target = e.target;
          // Walk up the DOM to find an anchor tag
          while (target && target.tagName !== 'A') {
            target = target.parentElement;
          }
          if (target && target.href) {
            var href = target.href;
            // Check if this is a download card link
            if (href.includes('download_card_image=true') || 
                (href.endsWith('.png') && !href.includes('aicharactercards.com/wp-content/uploads'))) {
              e.preventDefault();
              e.stopPropagation();
              // Send the URL to Flutter via platform-specific message handler
              $jsSendMessage;
              return false;
            }
          }
        }, true);
      })();
    ''');
    
    webview.launch('https://aicharactercards.com/');
  }

  Future<void> _openChubBrowser() async {
    final webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        title: 'Chub.ai - Character Hub',
        titleBarTopPadding: Platform.isMacOS ? 20 : 0,
      ),
    );
    webview.launch('https://chub.ai/');
  }

  void _showChubWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D1111),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text(
              '⚠️ TRAVELER, BEWARE ⚠️',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/eye_bleach.jpg',
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'You are about to enter Chub.ai — a land where content '
                'moderation is more of a suggestion than a rule.',
                style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'You WILL encounter NSFW and potentially NSFL content. '
                'There is no "safe" section. There is no lifeguard on duty. '
                'Eye bleach is strongly advised — and may still not be enough.',
                style: TextStyle(color: Colors.redAccent, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Browse at your own discretion. '
                'We are not responsible for what you find... '
                'or what finds you. 👁️',
                style: TextStyle(color: Colors.white60, fontSize: 12, fontStyle: FontStyle.italic, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nope, I Choose Life', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _openChubBrowser();
            },
            child: const Text('I Fear Nothing. Proceed.'),
          ),
        ],
      ),
    );
  }
}

