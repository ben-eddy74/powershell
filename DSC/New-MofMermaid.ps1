Function New-MofMermaid
{
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true)]
    [string] $MOFFile,

    [Parameter()]
    [ValidateSet('TB', 'TD', 'BT', 'RL', 'LR')]
    [string] $GraphDirection = 'TD'
  )

  $fileContent = Get-Content -Path $MOFFile -ErrorAction Stop

  $instance = ""

  # Create single line entry for each instance
  # This will ommit the last instance: instance of OMI_ConfigurationDocument
  #
  $instances = foreach($line in $fileContent)
  {
    if($line -like "instance of MSFT_Credential *" -or
       $line -like "instance of MSFT_SPWebAppAuthenticationMode *" -or
       $line -like "instance of cNtfsAccessControlInformation *")
    {
      Write-Verbose "Skipping unsupported entry"
      Write-Verbose "  $($line)"

      continue
    }#end if unsupported instances

    if($line -like "instance of *")
    {
      if($instance.Length -gt 0)
      {
        Write-Verbose "Finalize instance"
        Write-Output $instance
      }

      Write-Verbose "New instance: $($line)"

      $instance = $line
    }
    else
    {
      if($instance.Length -gt 0 -and $line.Length -gt 0)
      {
        $instance += " " + $line.Trim()
      }
    }#endif instance
  }#end foreach

  # Get instance details using regex and create a custom object for each
  # resource
  #
  $resources = foreach($item in $instances)
  {
    if($item -match 'instance of (?<ClassName>\w*) as \$(?<MofId>\w*).*(ResourceID = "(?<ResourceId>\[(?<ResourceName>\w*)](?<Name>\S*?))(::.*)?";)(.*DependsOn = { (?<DependsOn>.*)?};)?.*ConfigurationName = "(?<ConfigurationName>\w*)"; };')
    {
      $resource = [pscustomobject]@{
        ClassName    = $Matches.ClassName
        MofId        = $Matches.MofId
        ResourceId   = $Matches.ResourceId
        ResourceName = $Matches.ResourceName
        Name         = $Matches.Name
        DependsOn    = @()
        Dependants   = 0
        ConfigurationName = $Matches.ConfigurationName
      }

      # If resource depends on an other, create an array of resource id's
      #
      if($null -ne $Matches.DependsOn)
      {
        $Matches.DependsOn -split ',' | ForEach-Object { $resource.DependsOn += $_ }
      }

      $resource
    }
    else
    {
      Write-Warning "Unable to process `n$($item)`n"
    }#end if regex
  }#end foreach

  # Start output of Mermaid graph in Markdown format
  #
  Write-Output '```mermaid'

  # TODO: Make direction optional
  #
  Write-Output "graph $($GraphDirection)"

  # Output instances with dependencies first so they are drawn on the top left
  # of the graph.
  #
  $resources | Where-Object { $_.DependsOn.Count -gt 0 } | ForEach-Object {
    Foreach($Dependency in $_.DependsOn)
    {
      $Dependency = $Dependency.Replace('"', '').Trim()

      # Increase dependants on dependent resource so we can sort it
      #
      $Dependant = $resources | Where-Object { $_.ResourceId -eq $Dependency }
      $Dependant.Dependants += 1

      # Remove unsupported Mermaid characters
      #
      $Name = $_.ResourceId.Replace('[', '').Replace(']', '-')

      Write-Output "  $($Dependant.MofId) --> $($_.MofId)($Name)"
    }
  }

  # Output instances without dependents
  #
  $resources | Where-Object { $_.DependsOn.Count -eq 0 } | Sort-Object -Property Dependants -Descending | ForEach-Object {
    # Remove unsupported Mermaid characters
    #
    $Name = $_.ResourceId.Replace('[', '').Replace(']', '-')

    Write-Output "  $($_.MofId)($($Name))"
  }

  # Finish Markdown
  Write-Output '```'
}
