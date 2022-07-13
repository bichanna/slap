@ECHO OFF

SET RED=4
SET GREEN=2
SET LBLUE=9
SET NC=7

IF NOT EXIST "C:\Users\%USERNAME%\.nimble\bin\" (
ECHO Nim is not installed.
SET /p answer="Would you like to install Nim? [yes/no]: "
IF ( "%answer%"=="yes" ) (
REM I have no idea what to call here..
) ELSE (
ECHO Nim installation canceled
)
)

ECHO Building Slap...

nimble build --multimethods:on -d:release && (
REM Now that no errors were found, actually build.
nimble build --multimethods:on -d:release
REM Things of context misunderstood here.. (Please place code here.)
COLOR %GREEN%
ECHO Completed.
ECHO Usage: 'slap [filename]'
) || (
REM Failed Build Result.
COLOR %RED%
ECHO Failed
COLOR %NC%
ECHO Please run this command: 
COLOR %LBLUE%
ECHO nimble build --multimethods:on --verbose --debug
COLOR %NC%
ECHO And open an issue on Github: 
COLOR %LBLUE%
ECHO https://github.com/bichanna/slap/issues
)
