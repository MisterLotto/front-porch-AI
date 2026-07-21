# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.

## Recent improvements (unreleased — ships in the next build)

- 🔧 **Tool calling no longer gets stuck on "Not supported" after creating a visiting character.** Creating a Scene Guest mid-chat could knock the tool-calling status to "Not supported" and leave it there — the character creation was quietly interrupting a background request, and the app mistook that interruption for "this model can't do tool calling." Now character creation waits its turn instead of interrupting, and a dropped connection, a busy server, or a timeout is never counted against the model — the app simply retries tool calling on the next pass. (Thanks for the Discord report!)
