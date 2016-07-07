@echo off

cd %APPVEYOR_BUILD_FOLDER%
IF [%DEVOPS_BRANCH%] == [] (
	set DEVOPS_BRANCH=master
)

set MY_DEVOPS_DIR=.\external\project-renard\devops

IF %1 == install goto install
IF %1 == test goto test

:install

echo Cloning from devops [branch: %DEVOPS_BRANCH%]
git clone -b %DEVOPS_BRANCH% https://github.com/project-renard/devops.git external\project-renard\devops

%MY_DEVOPS_DIR%\script\from-curie\ci\appveyor\install.bat
goto end

REM ====================================

:test

%MY_DEVOPS_DIR%\script\from-curie\ci\appveyor\test.bat
goto end

REM ====================================

:end

