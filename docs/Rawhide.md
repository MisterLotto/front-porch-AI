# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.

## Recent improvements (unreleased — ships in the next build)

- 🧹 **Output Sanitizer — replace words and phrases the model keeps getting wrong.** Set up find-and-replace rules that clean up the AI's replies before they're saved to your chat history — on every backend, local or remote. Turn on the sanitizer in Chat Settings, add rules with exact text or limited regex patterns, and optionally apply them retroactively to existing chats (your own messages are never touched, and you'll be asked to confirm first). Stop sequences and banned phrases editors have been refreshed too.
- 🐛 **Per-chat generation settings no longer bleed between chats.** Opening chat B after chat A could silently leave B running on A's per-chat generation overrides (temperature, stop sequences, sanitizer rules, etc.) — including brand-new chats, which could even save A's overrides as their own. Every path into a chat now loads (or clears to) the right settings.
- ⚡ **Control whether the backend auto-starts when you open a chat.** The local backend previously started every time you entered a conversation. You can now turn this off in Settings → Backend ("Auto-start on chat open") — useful when you're just reading old messages or don't want the overhead of loading a local LLM. The toggle is on by default, so existing behavior is unchanged.
