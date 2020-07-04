﻿param (
	[string]$pkgXML = (Join-Path (Split-Path -parent $MyInvocation.MyCommand.Definition) 'packages.xml') ,
	[string]$PersonalPkgXML,
	[switch]$ThoroughList
)
$ErrorActionPreference = 'Stop'

#needed for accessing dotnet zip functions
Add-Type -AssemblyName System.IO.Compression.FileSystem

#needed to use [Microsoft.PowerShell.Commands.PSUserAgent] when running in pwsh
Import-Module Microsoft.PowerShell.Utility

#dot source functions from other file
$functionsFileA = (Join-Path (Split-Path -parent $MyInvocation.MyCommand.Definition) 'PkgFunctions-normal.ps1')
$functionsFileB = (Join-Path (Split-Path -parent $MyInvocation.MyCommand.Definition) 'PkgFunctions-special.ps1')
$functionsFileC = (Join-Path (Split-Path -parent $MyInvocation.MyCommand.Definition) 'OtherFunction.ps1')
$ExecutionContext.InvokeCommand.InvokeScript($false, ([scriptblock]::Create([io.file]::ReadAllText($functionsFileA, [Text.Encoding]::UTF8))), $null, $null)
$ExecutionContext.InvokeCommand.InvokeScript($false, ([scriptblock]::Create([io.file]::ReadAllText($functionsFileB, [Text.Encoding]::UTF8))), $null, $null)
$ExecutionContext.InvokeCommand.InvokeScript($false, ([scriptblock]::Create([io.file]::ReadAllText($functionsFileC, [Text.Encoding]::UTF8))), $null, $null)

#default dot source, too slow
#. (Join-Path (Split-Path -parent $MyInvocation.MyCommand.Definition) 'Custom-internalizer-funcs.ps1')

if (!($IsWindows) -or ($IsWindows -eq $true)) {
	$tempPathA = [IO.Path]::Combine($env:APPDATA, "internalizer", "personal-packages.xml" )
} elseif ($IsLinux -eq $true) {
	$tempPathA = [IO.Path]::Combine( $env:HOME, ".config" , "internalizer", "personal-packages.xml" )
} elseif ($IsMacOS -eq $true) {
	Throw "MacOS not supported"
} else {
	Throw "Something went wrong detecting OS"
}

$tempPathB = (Join-Path (Split-Path -parent $MyInvocation.MyCommand.Definition) 'personal-packages.xml')

if (!($PSBoundParameters.ContainsKey('PersonalPkgXML'))) {
	if (Test-Path $tempPathA) {
		$PersonalPkgXML = $tempPathA
	} elseif (Test-Path $tempPathB) {
		$PersonalPkgXML = $tempPathB
	} else {
		Throw "Cannot find personal-packages.xml, please specify path to it"
	}
	
} elseif (!(Test-Path $PersonalPkgXML)) {
	throw "personal-packages.xml not found, please specify valid path"
}

#(Join-Path (Split-Path -parent $MyInvocation.MyCommand.Definition) 'personal-packages.xml')

if (!(Test-Path $pkgXML)) {
	throw "packages.xml not found, please specify valid path"
}


[XML]$packagesXMLcontent = Get-Content $pkgXML
[XML]$personalpackagesXMLcontent = Get-Content $PersonalPkgXML

#change these to paramters? XML file?
#add check that workDir is not subdir of download dir
#add drop-path
$searchDir = $personalpackagesXMLcontent.mypackages.options.searchDir.tostring()
$workDir = $personalpackagesXMLcontent.mypackages.options.workDir.tostring()
$dropPath = $personalpackagesXMLcontent.mypackages.options.DropPath.tostring()
$useDropPath = $personalpackagesXMLcontent.mypackages.options.useDropPath.tostring()
$writePerPkgs = $personalpackagesXMLcontent.mypackages.options.writePerPkgs.tostring()
$pushURL = $personalpackagesXMLcontent.mypackages.options.pushURL.tostring()
$pushPkgs = $personalpackagesXMLcontent.mypackages.options.pushPkgs.tostring()

if (!(Test-Path $searchDir)) {
	throw "searchDir not found, please specify valid path"
}
if (!(Test-Path $workDir)) {
	throw "workDir not found, please specify valid path"
}
if ($useDropPath -eq "yes") {
	if (!(Test-Path $dropPath)) {
		throw "Drop path not found, please specify valid path"
	}
	
	for (($i= 0); ($i -le 12) -and ($null -ne $(Get-ChildItem -Path $dropPath -Filter "*.nupkg")) ; $i++ ) {
		Write-Output "Found files in the drop path, waiting 15 seconds for them to clear"
		Start-Sleep -Seconds 15
	}
	
	if ($null -ne $(Get-ChildItem -Path $dropPath -Filter "*.nupkg")) {
		Write-Warning "There are still files in the drop path"
	}
}

#need this as normal PWSH arrays are slow to add an element
[System.Collections.ArrayList]$nupkgObjArray = @()

#add switch here to select from other options to get list of nupkgs
if ($ThoroughList) {
	#Get-ChildItem $searchDir -File -Filter "*adopt*.nupkg" -Recurse
	$nupkgArray = Get-ChildItem -File $searchDir -Filter "*.nupkg" -Recurse
} else {
	#filters based on folder name, therefore less files to open later and therefore faster, but may not be useful in all circumstances. 
	$nupkgArray = (Get-ChildItem -File $searchDir  -Filter "*.nupkg" -Recurse) | Where-Object { 
		($_.directory.name -notin $packagesXMLcontent.packages.internal.id) `
		-and ($_.directory.Parent.name -notin $packagesXMLcontent.packages.internal.id) `
		-and ($_.directory.name -notin $personalpackagesXMLcontent.mypackages.personal.id) `
		-and ($_.directory.Parent.name -notin $personalpackagesXMLcontent.mypackages.personal.id) `
		}
}

#echo $nupkgArray.fullname
#unique needed to workaround bug if accessing from samba that some things show up twice
$nupkgArray | select -Unique | ForEach-Object {
	$script:status = "ready"
	$script:InstallScript = $null
	$versionDir	= $null
	$newpath = $null
	Get-NuspecVersion -NupkgPath $_.fullname
	$internalizedVersions = ($personalpackagesXMLcontent.mypackages.internalized.pkg | Where-Object {$_.id -eq "$nuspecID" }).version

	if ($internalizedVersions -icontains $nuspecVersion) {
		#package is internalized by user
		#add something here? verbose logging?
		
	} elseif ($packagesXMLcontent.packages.notImplemented.id -icontains $nuspecID) {
		Write-Output "$nuspecID $nuspecVersion  not implemented, requires manual internalization" #$nuspecVersion
		#package is not supported, due to bad choco install script that is hard to internalize
		#add something here? verbose logging?

	} elseif ($personalpackagesXMLcontent.mypackages.personal.id -icontains $nuspecID) {
		#package is personal custom package and is internal
		#add something here? verbose logging?

	} elseif ($packagesXMLcontent.packages.internal.id -icontains $nuspecID) {
		#package from chocolatey.org is internal by default
		#add something here? verbose logging?

 	} elseif ($packagesXMLcontent.packages.custom.pkg.id -icontains $nuspecID) {

		 Get-ZipInstallScript -NupkgPath $_.fullname

		if ($script:status -eq "noscript") {
			Write-Output "You may want to add $nuspecID $nuspecVersion to the internal list"
			#Write-Output '<id>'$nuspecID'</id>'

		} else {

			$idDir      = (Join-Path $workDir $Script:nuspecID)
			$versionDir = (Join-Path $idDir $Script:nuspecVersion)
			$newpath    = (Join-Path $Script:versionDir $_.name)
			$customXml  = $packagesXMLcontent.packages.custom.pkg | where-object id -eq $nuspecID
			$toolsDir   = (Join-Path $Script:versionDir "tools")

			if (($null -eq $customXml.functionName) -or ($customXml.functionName -eq "")) {
				Throw "Could not find function for $nuspecID"
			}
			
			$obj = [PSCustomObject]@{
				nupkgName     = $_.name
				origPath      = $_.fullname
				version       = $nuspecVersion
				nuspecID      = $nuspecID
				status        = $status
				idDir         = $idDir
				versionDir    = $versionDir
				toolsDir      = $toolsDir
				newPath       = $newpath
				#needsToolsDir = $customXml.needsToolsDir
				functionName   = $customXml.functionName
				#needsStopAction   = $customXml.needsStopAction
				installScriptOrig = $script:InstallScript
				installScriptMod  = $script:InstallScript

			}

			$nupkgObjArray.add($obj) | Out-Null

			Write-Output "Found $nuspecID $nuspecVersion to internalize"
			#Write-Output $_.fullname

		}


	} else {
		#Write-Output '<id>'$nuspecID'</id>'

		Write-Output "$nuspecID $nuspecVersion is new, id unknown"

		<#Get-InstallScript -NupkgPath $_.fullname

		if (!($script:InstallScript -like "*http*")) {
			Write-Output '<id>'$nuspecID'</id>'
		} #>
	}
}

#don't need the list anymore, use nupkgObjArray
$nupkgArray = $null

#Setup the directories for internalizing
Foreach ($obj in $nupkgObjArray) {
	try {
	
		if (!(Test-Path $obj.idDir)) {
			mkdir $obj.idDir | Out-Null
		}

		if (Test-Path $obj.versionDir) {
			New-Item -Path $obj.versionDir -Name "temp.txt" -ItemType file -ea 0 | Out-Null
			Remove-Item -ea 0 -Force -Recurse -Path (Get-ChildItem -Path $obj.versionDir -Exclude "tools","*.exe","*.msi","*.msu","*.zip")
		} else {
			mkdir $obj.versionDir | Out-Null
		}

		if (Test-Path $obj.toolsDir) {
			New-Item -Path $obj.toolsDir -Name "temp.txt" -ItemType file -ea 0 | Out-Null 
			Remove-Item -ea 0 -Force -Recurse -Path (Get-ChildItem -Path $obj.toolsDir -Exclude "*.exe","*.msi","*.msu","*.zip")
		} else {
			mkdir $obj.toolsDir | Out-Null
		}

		#Copy-Item $obj.OrigPath $obj.versionDir 
		$obj.status = "setup"
	} catch {
		$obj.status = "not-setup"
		Write-Host "failed to setup" $obj.nuspecID $obj.version
		Remove-Item -ea 0 -Force -Recurse -Path $obj.versionDir
	}
	
}

Foreach ($obj in $nupkgObjArray) {
	if ($obj.status -eq "setup") {
		#Try { 
			Write-Host "Starting " $obj.nuspecID
			Extract-Nupkg -obj $obj  

			#Write-Output $obj.functionName
			$tempFuncName = $obj.functionName
			$tempFuncName = $tempFuncName + ' -obj $obj'
			Invoke-Expression $tempFuncName
			$tempFuncName = $null
				
			#Write-Output $obj.filename64
			#Write-InstallScript -nupkgObj $obj
			#Write-Output "should show up only once"
			#Write-Output $obj.nuspecID $obj.version

			#OLD
			#Write-ToolsFiles -nupkg $obj.newPath -toolsDir $obj.toolsDir
			#Update-ContentTypes -nupkgPath $obj.newPath


			Write-UnzippedInstallScript -obj $obj

			#start choco pack in the correct directory
			$packcode = Start-Process -FilePath "choco" -ArgumentList 'pack -r' -WorkingDirectory $obj.versionDir -NoNewWindow -Wait -PassThru
			
			if ($packcode.exitcode -ne "0") {
				$obj.status = "pack failed"
			} else {
				$obj.status = "internalized"
			}
		#} Catch {
		#	$obj.status = "internalization failed"
		#}
	}
}



Foreach ($obj in $nupkgObjArray) {
	if ($obj.status -eq "internalized") {
		#Try {
			if ($useDropPath -eq "yes") {
				Copy-Item (Get-ChildItem $obj.versionDir -Filter "*.nupkg").fullname $dropPath
			}
			if ($writePerPkgs -eq "yes") {
				Write-PerPkg -obj $obj
			}
			if ($pushPkgs -eq "yes") {
				$pushArgs = 'push -r -s ' + $pushURL
				$pushcode = Start-Process -FilePath "choco" -ArgumentList $pushArgs -WorkingDirectory $obj.versionDir -NoNewWindow -Wait -PassThru
			}
			
			if (($pushPkgs -eq "yes") -and ($pushcode.exitcode -ne "0")) {
				$obj.status = "push failed"
			} else {
				$obj.status = "done"
			}
		#} Catch {
		#	$obj.status = "failed copy or write"
		#} 
	}
}



$nupkgObjArray | ForEach-Object {
	Write-Host $_.nuspecID $_.Version $_.status
}
#Write-Output "completed"

# Get-ChildItem -Recurse -Path '..\.nugetv2\F1' -Filter "*.nupkg" | % { Copy-Item $_.fullname . }

