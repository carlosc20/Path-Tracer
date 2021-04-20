@echo off
title Compiling optix
set input= optix/optix.cu
set output= out/optix.ptx
set optix_path=        "C:\ProgramData\NVIDIA Corporation\OptiX SDK 7.3.0\include"
set msvc_include_path= "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.28.29333\include"
set msvc_path=         "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.28.29333\bin\Hostx64\x64"


:start
cls
rem nvcc.exe -O3 -use_fast_math -arch=compute_30 -code=sm_30 -I %optix_path% -I %msvc_include_path% -I "." -m 64 -ptx -ccbin %msvc_path% %input% -o %output%
nvcc.exe -O3 -use_fast_math -I %optix_path% -I %msvc_include_path% -I "." -m 64 -ptx -ccbin %msvc_path% %input% -o %output%
set choice=
set /p choice="Press 'y' and enter to restart: "
if not '%choice%'=='' set choice=%choice:~0,1%
if '%choice%'=='y' goto start
