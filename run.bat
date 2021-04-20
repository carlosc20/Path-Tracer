@echo off
title Run project
set nau="C:\Users\CarlosPeixotoAntunes\Projects\nau\build\bin\composerImGui.exe"
set projects_dir="C:\Users\CarlosPeixotoAntunes\Projects\Path-Tracer\projects"

setlocal EnableDelayedExpansion

cd %projects_dir%
set i=0
for %%p in ("*.xml") do (
    set /A i=i+1
    set project[!i!]=%%p
    echo !i! %%p
)

set choice=
set /p choice="Enter project number to run: "
if not '%choice%'=='' set choice=%choice:~0,1%
if not [!project[%choice%]!] == [] %nau% "%projects_dir:"=%\!project[%choice%]!"