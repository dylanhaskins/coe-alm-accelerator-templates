    $solution = "ALMAcceleratorSampleSolution"
    $customDeploymentSettingsFilePath = "C:\Source\repos\customDeploymentSettings.json"
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
    $xrmDataPowerShellVersion = "2.8.12"
    #Install-Module Microsoft.Xrm.Data.PowerShell -Force -RequiredVersion $xrmDataPowerShellVersion
    $powerAppsAdminModuleVersion = "2.0.105"
    #Install-Module Microsoft.PowerApps.Administration.PowerShell -Force -RequiredVersion $powerAppsAdminModuleVersion
    $clientId = "28e0d2ac-8e83-459f-b910-ad206cf0b436"
    $clientSecret = "xCzV2ZX6d7QTl6nmct8yLPdjfOk4C2LR"
    $tenantId = "8a235459-3d2c-415d-8c1e-e2fe133509ad"
    $url = "https://contosocoedev.crm.dynamics.com/"
    $connstr = "AuthType=ClientSecret;ClientId=$clientId;ClientSecret=$clientSecret;Url=$url"
    $xrmDataPowerShellVersion = "2.8.12"
    $powerAppsAdminModuleVersion = "2.0.105"
    $conn = Get-CrmConnection -ConnectionString "AuthType=ClientSecret;ClientId=$clientId;ClientSecret=$clientSecret;Url=$url"
    $solutions = Get-CrmRecords -conn $conn -EntityLogicalName solution -FilterAttribute "uniquename" -FilterOperator "eq" -FilterValue $solution
    $solutionId = $solutions.CrmRecords[0].solutionid

    $solutionComponentResults =  Get-CrmRecords -conn $conn -EntityLogicalName solutioncomponent -FilterAttribute "solutionid" -FilterOperator "eq" -FilterValue $solutionId -Fields componenttype, solutioncomponentid, objectid
    $connectionReferences = [System.Collections.ArrayList]@()
    $environmentVariables = [System.Collections.ArrayList]@()
    $canvasApps = [System.Collections.ArrayList]@()
    $flows = [System.Collections.ArrayList]@()
    $groupTeams = [System.Collections.ArrayList]@()

    $currentConfiguration = @{}
    if(Test-Path $customDeploymentSettingsFilePath) {
        $existingDeploymentSettings = Get-Content $customDeploymentSettingsFilePath -Raw
        if(-Not [string]::IsNullOrWhiteSpace($existingDeploymentSettings)) {
            $currentConfiguration = ConvertFrom-Json $existingDeploymentSettings
        }
    }

    $currentConnectionReferences = $currentConfiguration.ConnectionReferences
    $currentEnvironmentVariables = $currentConfiguration.EnvironmentVariables
    $currentCanvasApps = $currentConfiguration.AadGroupCanvasConfiguration
    $currentFlows = $currentConfiguration.SolutionComponentOwnershipConfiguration
    $currentGroupTeams = $currentConfiguration.AadGroupTeamConfiguration

    foreach($solutioncomponent in $solutionComponentResults.CrmRecords)
    {
        #Connection Reference
        if($solutioncomponent.componenttype_Property.Value.Value -eq 10027) {
            #"ConnectionReferences": [
            #[ "cat_CDS_Current", "#{connection.cat_CDS_Current}#" ]
            #]
            $connRefResult = Get-CrmRecord -conn $conn -EntityLogicalName connectionreference -Id $solutionComponent.objectid -Fields connectionreferencelogicalname
            $connRef = $null
            $connRefName = $connRefResult.connectionreferencelogicalname
            $currentConnectionReferences | Foreach-Object { if($_ -ne $null -and $_[0] -eq $connRefName) { $connRef = $_ } }
            if($connRef -eq $null) {
                $connRef = [System.Collections.ArrayList]@()
                $connRef.Add($connRefResult.connectionreferencelogicalname)
                $connRef.Add("#{connectionreference." + $connRefName + "}#")
            }
            $connectionReferences.Add($connRef)
        }
        #Environment Variable Definition
        elseif($solutioncomponent.componenttype_Property.Value.Value -eq 380) {
            #"EnvironmentVariables": [
            #[ "cat_TextEnvironmentVariable", "#{variable.cat_TextEnvironmentVariable}#" ],
            #[ "cat_DecimalEnvironmentVariable", "#{variable.cat_DecimalEnvironmentVariable}#" ],
            #[ "cat_JsonEnvironmentVariable", "{\"name\":\"#{variable.cat_JsonEnvironmentVariable.name}#\"}" ]
            #]
            $envVarResult =  Get-CrmRecord -conn $conn -EntityLogicalName environmentvariabledefinition -Id $solutionComponent.objectid -Fields schemaname
            $envVar = $null
            $envVarName = $envVarResult.schemaname
            $currentEnvironmentVariables | Foreach-Object { if($_ -ne $null -and $_[0] -eq $envVarName) { $envVar = $_ } }

            if($envVar -eq $null) {
                $envVar = [System.Collections.ArrayList]@()
                $envVar.Add($envVarResult.schemaname)
                $envVar.Add("#{environmentvariable." + $envVarName + "}#")
            }
            $environmentVariables.Add($envVar)
        }
        #Canvas App
        elseif($solutioncomponent.componenttype_Property.Value.Value -eq 300) {
            #"AadGroupCanvasConfiguration": [
            #{
            #    "aadGroupId": "#{canvasshare.aadGroupId}#",
            #    "canvasNameInSolution": "cat_devopskitsamplecanvasapp_c7ec5",
            #    "canvasDisplayName": "cat_devopskitsamplecanvasapp_c7ec5",
            #    "roleName": "#{canvasshare.roleName}#"
            #}
            #]
            $canvasAppResult =  Get-CrmRecord -conn $conn -EntityLogicalName canvasapp -Id $solutionComponent.objectid -Fields solutionid, name, displayname
            $canvasConfig = $null
            $canvasName = $canvasAppResult.name
            $placeholdername = $canvasAppResult.displayname.replace(' ','')
            $currentCanvasApps | Foreach-Object { if($_.canvasNameInSolution -eq $canvasName) { $canvasConfig = $_ } }
            if($canvasConfig -eq $null) {
                $canvasConfig = @{"aadGroupId"="#{canvasshare.aadGroupId." + $canvasAppResult.displayname + "}#"; "canvasNameInSolution"=$canvasName; "canvasDisplayName"= $canvasAppResult.displayname; "roleName"="#{canvasshare.roleName." + $placeholdername + "}#"}
            }
            $canvasApps.Add($canvasConfig)
        }
        #Workflow
        elseif($solutioncomponent.componenttype_Property.Value.Value -eq 29) {
            #"SolutionComponentOwnershipConfiguration": [
            #{
            #  "solutionComponentType": 29,
            #  "solutionComponentUniqueName": "71cc728c-2487-eb11-a812-000d3a8fe6a3",
            #  "solutionComponentName": My Flow,
            #  "ownerEmail": "#{owner.ownerEmail}#"
            #},
            #{
            #  "solutionComponentType": 29,
            #  "solutionComponentUniqueName": "d2f7f0e2-a1a9-eb11-b1ac-000d3a53c3c2",
            #  "solutionComponentName": My Other Flow,
            #  "ownerEmail": "#{owner.ownerEmail}#"
            #}
            #]
            $flowResult =  Get-CrmRecord -conn $conn -EntityLogicalName workflow -Id $solutionComponent.objectid -Fields solutionid, name
            $flowConfig = $null
            $workflowName = $solutionComponent.objectid
            $placeholdername = $flowResult.name.replace(' ','')
            $currentFlows | Foreach-Object { if($_.solutionComponentUniqueName -eq $workflowName) { $flowConfig = $_ } }

            if($flowConfig -eq $null) {
                $flowConfig = @{"solutionComponentType"=$solutioncomponent.componenttype_Property.Value.Value; "solutionComponentName"=$flowResult.name; "solutionComponentUniqueName"=$workflowName; "ownerEmail"="#{owner.ownerEmail." + $placeholdername + "}#"}
            }
            $flows.Add($flowConfig)
        }
    }
    #"AadGroupTeamConfiguration": [
    #{
    #    "aadGroupTeamName": "alm-accelerator-sample-solution",
    #    "aadSecurityGroupId": "#{team.aadSecurityGroupId}#",
    #    "dataverseSecurityRoleNames": [
    #    "ALM Accelerator Sample Role"
    #    ]
    #}
    #]

    $placeholdername = $canvasAppResult.displayname.replace(' ','')
    $groupTeamConfig = @{
        "aadGroupTeamName"="Sample Group Team Name"
        "aadSecurityGroupId"="#{team.samplegroupteamname.aadSecurityGroupId}#"
        "dataverseSecurityRoleNames"=@(
            'Fluffy','Spot','Testtetststst'
        )
    }
    $groupTeams.Add($groupTeamConfig)

    $newConfiguration = [PSCustomObject]@{}
    $newConfiguration | Add-Member -MemberType NoteProperty -Name 'SolutionComponentOwnershipConfiguration' -Value $flows
    $newConfiguration | Add-Member -MemberType NoteProperty -Name 'AadGroupCanvasConfiguration' -Value $canvasApps
    $newConfiguration | Add-Member -MemberType NoteProperty -Name 'EnvironmentVariables' -Value $environmentVariables
    $newConfiguration | Add-Member -MemberType NoteProperty -Name 'ConnectionReferences' -Value $connectionReferences
    $newConfiguration | Add-Member -MemberType NoteProperty -Name 'AadGroupTeamConfiguration' -Value $groupTeams

    $json = ConvertTo-Json $newConfiguration
    echo $json
    Set-Content -Path $customDeploymentSettingsFilePath -Value $json