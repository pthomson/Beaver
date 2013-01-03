﻿function PSScriptRoot { $MyInvocation.ScriptName | Split-Path }

function Invoke-Pipeline([string]$path)
{
    Test-Path $path -ErrorAction Stop > $null

    $pipelineName = [IO.Path]::GetFileName($path)
    $pipelinePath = $path.TrimEnd('\', '/')

    Write-Host "Pipeline $($pipelinePath) executing." -ForegroundColor Green

    Get-ChildItem  "$($pipelinePath)\*" | Sort -Property $_.Name | foreach { 
        Write-Host "Executing pipeline item $($_.Name)" -ForegroundColor Cyan
    
        $providerPath = "$(PSScriptRoot)\Pipeline Providers\$($_.Extension.TrimStart('.')).ps1"

        if(!(Test-Path $providerPath)) {
            Log-Warning "Pipeline Provider not found for $($_.FullName)! Skipping item. Expected provider path was $($providerPath)"
            return
        }

        $pipelineItemPath = $_.FullName
        
        try {
            & $providerPath
        }
        catch {
            Write-Host "Error occurred running $pipelineItemPath (exception)." -ForegroundColor Red
            Write-Host $_ -ForegroundColor Red
            exit 1
        }
    }

    Write-Host "Pipeline $($pipelinePath) complete." -ForegroundColor Green
}

# Invokes a "Cascade" of pipelines. All pipelines contained in $pipelinePath are executed in order
# Then, after each root pipeline exists, all pipelines of the same name in any of the cascade paths are also executed (eg 'extending' the base pipeline)
# Finally, any pipelines in the cascade paths that are NOT present in $pipelinePath are executed (eg 'custom' pipelines)
function Invoke-Pipeline-Cascade([string]$pipelinePath, [string[]]$cascadePaths) {
    # get all pipelines in primary
    $pipelines = Get-ChildItem $pipelinePath -Directory
    
    # execute pipelines in order, and if pipeline exists in any cascades execute that immediately afterwards
    $pipelines | ForEach-Object {
        $pipeline = $_

        Invoke-Pipeline $pipeline.FullName

        $cascadePaths | ForEach-Object {
            $cascadePath = Join-Path $_ $pipeline.Name

            if(Test-Path $cascadePath) {
                Invoke-Pipeline $cascadePath
            }
        }
    }

    # now we execute any custom pipelines in the cascades that are NOT defined in the primary
    $cascadePaths | ForEach-Object {
        $cascade = $_

        $cascadePipelines = Get-ChildItem $cascade -Directory -ErrorAction SilentlyContinue

        if($? -eq $true) {
            $cascadePipelines | ForEach-Object {
                $cascadePipeline = $_

                $primaryPath = Join-Path $pipelinePath $cascadePipeline.Name

                if(!(Test-Path $primaryPath)) {
                   Invoke-Pipeline $primaryPath
                }
            }
        }
    }
}