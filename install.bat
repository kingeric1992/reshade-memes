@echo off
set /p dir="Input ReShade Dir: "
set "rPath=%dir%\ReShade.ini"
set "sub=,%~dp0"

setlocal EnableExtensions DisableDelayedExpansion
> "%rPath%.tmp" (
  for /f "tokens=*" %%a in ('findstr /N "^" "%rPath%"') do (
    set line=%%a
    setlocal enableDelayedExpansion
    for /f "tokens=1,2 delims==" %%b in ("!line!") do (
      set val=%%c
      set key=%%b
      set key=!key:*:=!
      if "!key!" == "EffectSearchPaths" (
        echo(!key!=!val:%sub%=!,%~dp0
      ) else (
        if "!key!" == "TextureSearchPaths" (
          echo(!key!=!val:%sub%=!,%~dp0
        ) else (
          echo(!line:*:=!
        )
      )
    )
    endlocal
  )
)
endlocal
del "%rPath%"
ren "%rPath%.tmp" ReShade.ini