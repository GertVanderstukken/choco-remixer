﻿$moduleFile = [system.io.path]::Combine((Split-Path -Parent $PSScriptRoot), 'choco-remixer', 'choco-remixer.psm1')
Import-Module $moduleFile -Force
Invoke-InternalizeChocoPkg -personalPkgXML personal-packages-testing.xml -nosave