#
# Copyright Daniel Hutmacher under Creative Commons 4.0 license with attribution.
# http://creativecommons.org/licenses/by/4.0/
#
# Usage: Script-DBObjects -Server "server\instance" -DatabaseName "db" -Path "c:\temp"
#

Import-Module SqlServer

function Script-DBObjects([string]$Server, [string]$DatabaseName, [string]$Path) {

    # Check if a folder exists, and create it (including the whole path) if it doesn't.
    function Create-Folder([string]$path) {
        $global:foldPath = $null
        foreach($foldername in $path.split("\")) {
            $global:foldPath += ($foldername+"\")
            if (!(Test-Path $global:foldPath)){
                New-Item -ItemType Directory -Path $global:foldPath | Out-Null
            }
        }
    }

    # Source: https://flamingkeys.com/convert-camel-case-to-space-delimited-display-name-with-powershell/
    function Format-CamelCase([string]$inString) {
      $newString = ""
      $stringChars = $inString.GetEnumerator()
      $charIndex = 0
      foreach ($char in $stringChars) {
        # If upper and not first character, add a space
        if ([char]::IsUpper($char) -eq "True" -and $charIndex -gt 0) {
          $newString = $newString + " " + $char.ToString()
        } elseif ($charIndex -eq 0) {
          # If the first character, make it a capital always
          $newString = $newString + $char.ToString().ToUpper()
        } else {
          $newString = $newString + $char.ToString()
        }
        $charIndex++
      }
      $newString.ToString()
    }




    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO.Server") | Out-Null
    $SMOserver = New-Object ("Microsoft.SqlServer.Management.SMO.Server") -argumentlist $Server
    $Database = $SMOserver.databases[$DatabaseName]

    $ScriptOptions = New-Object ("Microsoft.SqlServer.Management.Smo.ScriptingOptions")
   #$ScriptOptions.ContinueScriptingOnError = $true
    $ScriptOptions.ScriptOwner = $true
    $ScriptOptions.ToFileOnly = $true
    $ScriptOptions.AppendToFile = $false
    $ScriptOptions.AnsiPadding = $true
    $ScriptOptions.Bindings = $true
    $ScriptOptions.ChangeTracking = $true
    $ScriptOptions.DriAll = $true
   #$ScriptOptions.EnforceScriptingOptions = $true
    $ScriptOptions.ExtendedProperties = $true
    $ScriptOptions.FullTextCatalogs = $true
    $ScriptOptions.FullTextIndexes = $true
    $ScriptOptions.FullTextStopLists = $true
    $ScriptOptions.IncludeDatabaseRoleMemberships = $true
    $ScriptOptions.IncludeFullTextCatalogRootPath = $true
    $ScriptOptions.IncludeHeaders = $false
    $ScriptOptions.Indexes = $true
    $ScriptOptions.LoginSid = $true
    $ScriptOptions.Permissions = $false
    $ScriptOptions.SchemaQualify = $true
    $ScriptOptions.SchemaQualifyForeignKeysReferences = $true
    $ScriptOptions.ScriptBatchTerminator = $true
    $ScriptOptions.ScriptDataCompression = $true
    $ScriptOptions.ScriptOwner = $false
    $ScriptOptions.ScriptSchema = $true
    $ScriptOptions.Statistics = $false
    $ScriptOptions.Triggers = $false
    $ScriptOptions.XmlIndexes = $true

    # These are the objects we want to script:
    $Objects  = $Database.Schemas
    $Objects += $Database.PartitionFunctions
    $Objects += $Database.PartitionSchemes
    $Objects += $Database.Sequences
    $Objects += $Database.Tables
    $Objects += $Database.Views
    $Objects += $Database.UserDefinedFunctions
    $Objects += $Database.UserDefinedTypes
    $Objects += $Database.UserDefinedTableTypes
    $Objects += $Database.StoredProcedures

    # Loop through each object:
    foreach ($Object in $Objects | where { ($_.Schema -eq $null) -or !($_.IsSystemObject)}) {

        if ($Object -ne $null) {
            $TypeName = Format-CamelCase ($Object.GetType().Name+"s")

            # Build folder structure
            if ($Object.Schema -eq $null) {
                $Folder=$path+"\"+$TypeName
            } else {
                $Folder=$path+"\"+$Object.Schema+"\"+$TypeName
            }

            # Create the folder if it doesn't exist:
            Create-Folder $Folder

            # File name:
            $ScriptFile = $Object.Name
            "$Folder\$ScriptFile.sql"
            $ScriptOptions.FileName="$Folder\$ScriptFile.sql"

            # Script the object:
            $Object.Script($ScriptOptions)

            # Separate the triggers from the regular tables/views:
            foreach($trigger in $Object.Triggers) {
                # Folder structure for triggers:
                $Folder=$path+"\"+$Object.Schema+"\Triggers"
                Create-Folder $Folder

                # File name:
                $ScriptFile = $trigger.Name
                "$Folder\$ScriptFile.sql"
                $ScriptOptions.FileName="$Folder\$ScriptFile.sql"

                # Out you go:
                $trigger.Script($ScriptOptions)
            }
        }
    }
}
