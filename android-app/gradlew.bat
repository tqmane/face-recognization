@rem Gradle wrapper script for Windows
@if "%DEBUG%"=="" @echo off
setlocal

set DIRNAME=%~dp0
if "%DIRNAME%"=="" set DIRNAME=.

java -jar "%DIRNAME%/gradle/wrapper/gradle-wrapper.jar" %*
