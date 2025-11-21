# Java 21 upgrade helper

This project has been prepared to target Java 21 (LTS). The automated Copilot upgrade tool could not be run from this environment (requires an upgraded Copilot plan), so a minimal Maven build was added so you can build and verify the project using Java 21.

What I added
- `pom.xml` — configures Maven to compile with Java 21 using `<release>21`.
- `.github/workflows/ci.yml` — GitHub Actions workflow that builds the project on Java 21 to validate the upgrade.

How to build locally

1) Install a Java 21 JDK (Adoptium / Eclipse Temurin, Azul, Oracle, etc.)

Windows (PowerShell):

```powershell
# After installing a JDK, set JAVA_HOME and update PATH (replace path with your JDK 21 install)
setx JAVA_HOME "C:\Program Files\Eclipse Adoptium\jdk-21"
setx PATH "%JAVA_HOME%\bin;${env:PATH}"
```

WSL (bash):

```bash
# Example: install OpenJDK 21 via your distro's package manager if available, or use sdkman
# Then ensure java -version reports 21
java -version
```

2) Build with Maven (from project root):

```bash
mvn -B clean package
```

If Maven builds successfully on Java 21, the project is effectively upgraded to run under Java 21.

Notes & next steps
- If you prefer Gradle instead of Maven, I can add a `build.gradle` equivalent.
- If you'd like me to try the automated OpenRewrite-based upgrade again, we can do so after upgrading the Copilot plan or by running OpenRewrite locally via the Maven plugin/CLI — tell me which you prefer.
