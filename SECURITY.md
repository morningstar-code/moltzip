# Security

To report a security problem, open an [issue](https://github.com/morningstar-code/moltzip/issues/new/choose) that says you have a security report, without the details, and a private channel will be arranged. Attach a minimal crafted archive that shows the problem rather than a real download.

MoltZip works only with local files: it reads the archive it is given, writes the extracted files, and shrinks or deletes the archive as it goes. It makes no network connections, has no telemetry and no accounts, and never saves archive passwords.

Every release file has a `.sha256` checksum next to it; see [Verify your download](https://morningstar-code.github.io/moltzip/verify.html).
