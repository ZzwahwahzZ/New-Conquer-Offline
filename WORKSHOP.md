# Browser-based AI coding workshop

This repository includes a GitHub Codespaces setup for running OpenCode Web in a private forwarded port.

## What the setup does
- Keeps the repository and working files in GitHub Codespaces rather than on the user's phone.
- Installs OpenCode once when the Codespace is created.
- Starts OpenCode Web automatically whenever the Codespace starts.
- Forwards port 4096 as a **private** port and also protects OpenCode with a generated password.
- Keeps the generated login file and server logs out of Git using .gitignore.

## First launch
1. Open the repository in GitHub Codespaces and create a Codespace from the `main` branch.
2. Wait for the container setup to finish. OpenCode Web should start automatically.
3. In the Codespaces Ports tab, open the private forwarded port labelled **OpenCode Web**.
4. Use username `opencode` and the password shown in the workspace file `.opencode-login.txt`.
5. Choose/connect an AI model provider in OpenCode. Free model availability and limits are controlled by the provider and can change; this repository does not promise unlimited free inference.

## Daily use and saving work
- Before finishing, save changes and commit/push them to GitHub.
- Stop the Codespace from GitHub's Codespaces page when finished. Closing the browser tab alone does not stop compute usage.
- Start the same Codespace later to continue. The repository workspace persists while the Codespace is retained.

## Security
- Port 4096 is configured as private.
- OpenCode Web uses HTTP Basic Authentication with a random password generated inside the Codespace.
- The password file is ignored by Git and must never be committed or shared.
- Do not change the forwarded port to public.

## Scope and project safety
Read `README.md` and `AGENTS.md` before making project changes. The original game files must remain unchanged unless a specific task explicitly authorizes a change.
