@echo off

cd %APPVEYOR_BUILD_FOLDER%

IF %COMPILER%==msys2 (
  @echo on
  SET "PATH=C:\%MSYS2_DIR%\%MSYSTEM%\bin;C:\%MSYS2_DIR%\usr\bin;%PATH%"
  SET DEVOPS_PATH=external/project-renard/devops
  bash -lc ". $APPVEYOR_BUILD_FOLDER/$DEVOPS_PATH/script/from-curie/ci/appveyor/run-test.sh"
)
